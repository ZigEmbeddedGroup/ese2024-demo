const std = @import("std");
const microzig = @import("microzig");
const drivers = @import("drivers");
const z2d = @import("z2d");

const rp2040 = microzig.hal;
const time = rp2040.time;
const gpio = rp2040.gpio;

const led = gpio.num(25);

const uart = rp2040.uart.instance.num(0);
const i2c = rp2040.i2c.instance.num(0);

const baud_rate = 115200;

const uart_tx_pin = gpio.num(0);
const uart_rx_pin = gpio.num(1);

const i2c_scl_pin = gpio.num(17);
const i2c_sda_pin = gpio.num(16);

const enc_button = gpio.num(18);
const enc_a = gpio.num(19);
const enc_b = gpio.num(20);

const pin_config = rp2040.pins.GlobalConfiguration{
    .GPIO25 = .{
        .name = "led",
        .direction = .out,
    },
};

pub fn panic(message: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    std.log.err("panic: {s}", .{message});
    @breakpoint();
    while (true) {}
}

pub const microzig_options = .{
    .log_level = .debug,
    .logFn = rp2040.uart.logFn,
};

const Digital_IO = struct {
    const State = drivers.base.DigitalIO.State;
    const Direction = drivers.base.DigitalIO.Direction;

    pin: gpio.Pin,

    pub fn set_direction(dio: Digital_IO, dir: Direction) !void {
        dio.pin.set_direction(switch (dir) {
            .output => .out,
            .input => .in,
        });
    }

    pub fn set_bias(dio: Digital_IO, maybe_bias: ?State) !void {
        dio.pin.set_pull(if (maybe_bias) |bias| switch (bias) {
            .low => .down,
            .high => .up,
        } else .disabled);
    }

    pub fn write(dio: Digital_IO, state: State) !void {
        dio.pin.put(state.value());
    }

    pub fn read(dio: Digital_IO) !State {
        return @enumFromInt(dio.pin.read());
    }
};

const I2C_Device = struct {
    address: rp2040.i2c.Address,

    pub fn connect(dd: I2C_Device) !void {
        _ = dd;
    }

    pub fn disconnect(dd: I2C_Device) void {
        _ = dd;
    }

    pub fn write(dd: I2C_Device, data: []const u8) !void {
        try i2c.write_blocking(dd.address, data, null);
    }
};

const SSD1306 = drivers.display.ssd1306.SSD1306_Generic(I2C_Device, .{
    .i2c_prefix = true,
    .buffer_size = 256,
});

const RotaryEncoder = drivers.input.rotary_encoder.RotaryEncoder_Generic(Digital_IO);
const DebouncedButton = drivers.input.debounced_button.DebouncedButton_Generic(Digital_IO, .low, null);

/// The splash bitmap we show before pressing the first button:
const splash_bitmap_data: *const [8 * 128]u8 = @embedFile("ese-splash.raw");

var framebuffer = drivers.display.ssd1306.Framebuffer.init(.black);

pub fn main() !void {
    const pins = pin_config.apply();

    uart_tx_pin.set_function(.uart);
    uart_rx_pin.set_function(.uart);

    i2c_scl_pin.set_function(.i2c);
    i2c_sda_pin.set_function(.i2c);

    enc_button.set_function(.sio);
    enc_a.set_function(.sio);
    enc_b.set_function(.sio);

    uart.apply(.{
        .baud_rate = baud_rate,
        .clock_config = rp2040.clock_config,
    });

    rp2040.uart.init_logger(uart);

    std.log.info("set up i2c...", .{});

    try i2c.apply(.{
        .clock_config = rp2040.clock_config,
        .baud_rate = 400_000,
    });

    std.log.info("set up rotary encoder...", .{});

    var input_button = try DebouncedButton.init(Digital_IO{
        .pin = enc_button,
    });

    var encoder = try RotaryEncoder.init(
        Digital_IO{ .pin = enc_a },
        Digital_IO{ .pin = enc_b },
        .high,
    );

    std.log.info("set up display...", .{});

    var display = try SSD1306.init(I2C_Device{
        .address = rp2040.i2c.Address.new(0b011_1100),
    });

    try display.write_full_display(splash_bitmap_data);

    std.log.info("wait for button press...", .{});

    // wait for user to press the button:
    while (try input_button.poll() != .pressed) {
        //
    }

    try display.write_full_display(framebuffer.bit_stream());

    // wait for user to release the button:
    while (try input_button.poll() != .released) {
        //
    }

    std.log.info("start application loop.", .{});

    var level: u7 = 64;

    try paint_gauge(&display, level);

    while (true) {
        const rot_event = try encoder.poll();
        switch (rot_event) {
            .idle => {},
            .increment => {
                level +|= 8;
                std.log.info("encoder: increment to {}", .{level});
                try paint_gauge(&display, level);
            },
            .decrement => {
                level -|= 8;
                std.log.info("encoder: decrement to {}", .{level});
                try paint_gauge(&display, level);
            },
            .@"error" => {},
        }

        const btn_event = try input_button.poll();
        switch (btn_event) {
            .idle => {},
            .pressed => {
                level = 64;
                std.log.info("button: reset to {}", .{level});
                try paint_gauge(&display, level);
            },
            .released => {},
        }
    }

    var cnt: u8 = 0;

    while (true) {
        pins.led.toggle();
        time.sleep_ms(100);
        std.log.info("blinky {}", .{cnt});
        cnt += 1; // will panic after 255 blinks
    }
}

var heap_memory: [128 * 1024]u8 = undefined;

fn paint_gauge(display: *SSD1306, level: u7) !void {
    var heap_allocator = std.heap.FixedBufferAllocator.init(&heap_memory);
    errdefer std.log.err("out of memory after {} bytes", .{heap_allocator.end_index});

    // var logging_allocator = std.heap.loggingAllocator(heap_allocator.allocator());
    // const allocator = logging_allocator.allocator();

    const allocator = heap_allocator.allocator();

    const width = 128;
    const height = 64;
    const surface = try z2d.Surface.init(.image_surface_alpha8, allocator, width, height);
    defer surface.deinit();

    std.log.info("surface ready", .{});

    var context: z2d.Context = .{
        .surface = surface,
        .pattern = .{
            .opaque_pattern = .{
                .pixel = .{ .rgb = .{ .r = 0xFF, .g = 0xFF, .b = 0xFF } },
            },
        },
        .anti_aliasing_mode = .none,
        .line_width = 1.0,
    };

    std.log.info("context ready", .{});

    const float_level = @as(f32, @floatFromInt(level)) / std.math.maxInt(@TypeOf(level));

    try fillMark(allocator, &context, float_level);

    std.log.info("fill done", .{});

    framebuffer.clear(.black);

    for (0..64) |y| {
        for (0..128) |x| {
            const pixel = surface.image_surface_alpha8.getPixel(@intCast(x), @intCast(y)) catch unreachable;

            framebuffer.set_pixel(
                @intCast(x),
                @intCast(y),
                if (pixel.alpha8.a > 0x80)
                    .white
                else
                    .black,
            );
        }
    }

    std.log.info("begin render", .{});
    try display.write_full_display(framebuffer.bit_stream());
    std.log.info("end render", .{});
}

/// Generates and fills the path for the Zig mark.
fn fillMark(alloc: std.mem.Allocator, context: *z2d.Context, float_level: f32) !void {
    var path = z2d.Path.init(alloc);
    defer path.deinit();

    std.log.info("path ready", .{});

    // Paint gauge optics:
    // M 64 54
    // L 96 22
    // C 80 4 48 4 32 22
    // Z

    try path.moveTo(64, 54);
    try path.lineTo(96, 22);
    try path.curveTo(80, 4, 48, 4, 32, 22);
    try path.close();

    context.line_width = 2.0;
    try context.stroke(alloc, path);
    path.reset();

    // Paint gauge meter:
    // virtual arc:
    //  M 109 54
    //  a 1 1 0 0 0 -90 0 # means radius = 45

    const ang_base = -40 * std.math.rad_per_deg;
    const ang_range = 80 * std.math.rad_per_deg;
    const radius_digit = 35;
    const radius_mark_in = 38;
    const radius_mark_out = 45;

    for (0..10) |tick| {
        const perc: f32 = @as(f32, @floatFromInt(tick)) / 9;

        const ang = ang_base + perc * ang_range;

        const dx = @sin(ang);
        const dy = @cos(ang);

        try path.lineTo(64 + radius_mark_in * dx, 54 - radius_mark_in * dy);
        try path.lineTo(64 + radius_mark_out * dx, 54 - radius_mark_out * dy);

        context.line_width = 1.5;
        try context.stroke(alloc, path);
        path.reset();
    }

    {
        const ang = ang_base + float_level * ang_range;

        const dx = radius_digit * @sin(ang);
        const dy = radius_digit * @cos(ang);

        try path.moveTo(64, 54);
        try path.lineTo(64 + dx, 54 - dy);

        context.line_width = 1.0;
        try context.stroke(alloc, path);
        path.reset();
    }

    std.log.info("graphic filled", .{});
}
