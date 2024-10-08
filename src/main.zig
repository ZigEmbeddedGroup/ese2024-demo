const std = @import("std");
const microzig = @import("microzig");
const z2d = @import("z2d");

const Framebuffer = drivers.display.ssd1306.Framebuffer;

const drivers = microzig.drivers;
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
    const State = drivers.base.Digital_IO.State;
    const Direction = drivers.base.Digital_IO.Direction;

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

const SSD1306 = drivers.display.ssd1306.SSD1306_Generic(.{
    .mode = .i2c,
    .buffer_size = 256,
    .Datagram_Device = I2C_Device,
});

const RotaryEncoder = drivers.input.Rotary_Encoder(.{
    .Digital_IO = Digital_IO,
});

const DebouncedButton = drivers.input.Debounced_Button(.{
    .active_state = .low,
    .Digital_IO = Digital_IO,
});

/// The splash bitmap we show before pressing the first button:
const splash_bitmap_data: *const [8 * 128]u8 = @embedFile("ese-splash.raw");

var static_framebuffer = Framebuffer.init(.black);
var dynamic_framebuffer = Framebuffer.init(.black);

pub fn main() !void {
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

    try render_content(&static_framebuffer, StaticGraphic{});

    std.log.info("wait for button press...", .{});

    // wait for user to press the button:
    while (try input_button.poll() != .pressed) {
        //
    }

    // wait for user to release the button:
    while (try input_button.poll() != .released) {
        //
    }

    std.log.info("start application loop.", .{});

    var level: u7 = 64;

    try redraw_app(&display, level);

    while (true) {
        const rot_event = try encoder.poll();
        switch (rot_event) {
            .idle => {},
            .increment => {
                level +|= 2;
                std.log.info("encoder: increment to {}", .{level});
                try redraw_app(&display, level);
            },
            .decrement => {
                level -|= 2;
                std.log.info("encoder: decrement to {}", .{level});
                try redraw_app(&display, level);
            },
            .@"error" => {},
        }

        const btn_event = try input_button.poll();
        switch (btn_event) {
            .idle => {},
            .pressed => {
                level = 64;
                std.log.info("button: reset to {}", .{level});
                try redraw_app(&display, level);
            },
            .released => {},
        }
    }
}

var heap_memory: [128 * 1024]u8 = undefined;

fn redraw_app(display: *SSD1306, level: u7) !void {
    try render_content(&dynamic_framebuffer, DynamicGraphic{
        .level = level,
    });

    overlay_framebuffer(&dynamic_framebuffer, &static_framebuffer);

    try display.write_full_display(dynamic_framebuffer.bit_stream());
}

fn overlay_framebuffer(dst: *Framebuffer, src: *const Framebuffer) void {
    for (&dst.pixel_data, &src.pixel_data) |*d, s| {
        d.* |= s;
    }
}

fn copy_surface_to_framebuffer(surface: *const z2d.Surface, framebuffer: *Framebuffer) void {
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
}

const graphic = struct {
    const ang_base = -40 * std.math.rad_per_deg;
    const ang_range = 80 * std.math.rad_per_deg;
    const radius_digit = 35;
    const radius_mark_in = 38;
    const radius_mark_out = 45;
};

fn render_content(framebuffer: *Framebuffer, renderer: anytype) !void {
    var heap_allocator = std.heap.FixedBufferAllocator.init(&heap_memory);
    errdefer std.log.err("out of memory after {} bytes", .{heap_allocator.end_index});

    // var logging_allocator = std.heap.loggingAllocator(heap_allocator.allocator());
    // const allocator = logging_allocator.allocator();

    const allocator = heap_allocator.allocator();

    const surface = try z2d.Surface.init(
        .image_surface_alpha8,
        allocator,
        Framebuffer.width,
        Framebuffer.height,
    );
    defer surface.deinit();

    // std.log.info("surface ready", .{});

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

    // std.log.info("context ready", .{});

    try renderer.draw(allocator, &context);

    // std.log.info("fill done", .{});

    copy_surface_to_framebuffer(&surface, framebuffer);
}

const DynamicGraphic = struct {
    level: u7,

    pub fn draw(self: DynamicGraphic, alloc: std.mem.Allocator, context: *z2d.Context) !void {
        const float_level = @as(f32, @floatFromInt(self.level)) / std.math.maxInt(@TypeOf(self.level));

        var path = z2d.Path.init(alloc);
        defer path.deinit();

        {
            const ang = graphic.ang_base + float_level * graphic.ang_range;

            const dx = graphic.radius_digit * @sin(ang);
            const dy = graphic.radius_digit * @cos(ang);

            try path.moveTo(64, 54);
            try path.lineTo(64 + dx, 54 - dy);

            context.line_width = 1.0;
            try context.stroke(alloc, path);
            path.reset();
        }

        // std.log.info("graphic filled", .{});
    }
};

const StaticGraphic = struct {
    pub fn draw(self: StaticGraphic, alloc: std.mem.Allocator, context: *z2d.Context) !void {
        _ = self;

        var path = z2d.Path.init(alloc);
        defer path.deinit();

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

        for (0..10) |tick| {
            const perc: f32 = @as(f32, @floatFromInt(tick)) / 9;

            const ang = graphic.ang_base + perc * graphic.ang_range;

            const dx = @sin(ang);
            const dy = @cos(ang);

            try path.lineTo(64 + graphic.radius_mark_in * dx, 54 - graphic.radius_mark_in * dy);
            try path.lineTo(64 + graphic.radius_mark_out * dx, 54 - graphic.radius_mark_out * dy);

            context.line_width = 1.5;
            try context.stroke(alloc, path);
            path.reset();
        }
    }
};
