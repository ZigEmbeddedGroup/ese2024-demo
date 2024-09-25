const std = @import("std");
const microzig = @import("microzig");
const rp2040 = microzig.hal;
const time = rp2040.time;
const gpio = rp2040.gpio;

const led = gpio.num(25);
const uart = rp2040.uart.instance.num(0);
const baud_rate = 115200;
const uart_tx_pin = gpio.num(0);
const uart_rx_pin = gpio.num(1);

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

pub fn main() !void {
    const pins = pin_config.apply();

    uart_tx_pin.set_function(.uart);
    uart_rx_pin.set_function(.uart);

    uart.apply(.{
        .baud_rate = baud_rate,
        .clock_config = rp2040.clock_config,
    });

    rp2040.uart.init_logger(uart);

    var cnt: u8 = 0;

    while (true) {
        pins.led.toggle();
        time.sleep_ms(100);
        std.log.info("blinky {}", .{cnt});
        cnt += 1; // will panic after 255 blinks
    }
}
