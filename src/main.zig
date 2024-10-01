const std = @import("std");
const microzig = @import("microzig");
const drivers = @import("drivers");

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
                level +|= 1;
                std.log.info("encoder: increment to {}", .{level});
                try paint_gauge(&display, level);
            },
            .decrement => {
                level -|= 1;
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

fn paint_gauge(display: *SSD1306, level: u7) !void {
    framebuffer.clear(.black);

    framebuffer.set_pixel(level, 31, .white);
    framebuffer.set_pixel(level, 32, .white);

    std.log.info("begin render", .{});
    try display.write_full_display(framebuffer.bit_stream());
    std.log.info("end render", .{});
}
