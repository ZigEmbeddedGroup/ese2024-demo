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

const SSD1306 = drivers.display.ssd1306.SSD1306_Generic(I2C_Device);

pub fn main() !void {
    const pins = pin_config.apply();

    uart_tx_pin.set_function(.uart);
    uart_rx_pin.set_function(.uart);

    i2c_scl_pin.set_function(.i2c);
    i2c_sda_pin.set_function(.i2c);

    uart.apply(.{
        .baud_rate = baud_rate,
        .clock_config = rp2040.clock_config,
    });

    rp2040.uart.init_logger(uart);

    try i2c.apply(.{
        .clock_config = rp2040.clock_config,
    });

    var display = try SSD1306.init(I2C_Device{
        .address = rp2040.i2c.Address.new(0b011_1100),
    });

    for (0..8) |_| {
        try display.clear_screen(true);
        time.sleep_ms(250);
        try display.clear_screen(false);
        time.sleep_ms(250);
    }

    var cnt: u8 = 0;

    while (true) {
        pins.led.toggle();
        time.sleep_ms(100);
        std.log.info("blinky {}", .{cnt});
        cnt += 1; // will panic after 255 blinks
    }
}
