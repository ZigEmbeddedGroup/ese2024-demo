//!
//! This example blinks the LED attached to GPIO25 on the Pi Pico.
//!

const std = @import("std");
const microzig = @import("microzig");
const rp2040 = microzig.hal;

// LED blinking:
const led_pin = rp2040.gpio.num(25);

// UART debugging:
const baud_rate = 115200;

const uart_tx_pin = rp2040.gpio.num(0);
const uart_rx_pin = rp2040.gpio.num(1);

const uart = rp2040.uart.instance.num(0);

// Configure MicroZig to use RP2040 uart logging:
pub const microzig_options = .{
    .log_level = .debug,
    .logFn = rp2040.uart.logFn,
};

pub fn main() !void {
    led_pin.set_function(.sio); // Set to "GPIO"
    led_pin.set_direction(.output); // Set as output

    // Route the UART to our selected pins:
    uart_tx_pin.set_function(.uart);
    uart_rx_pin.set_function(.uart);

    // Configure the UART with a compile-time known configuration:
    uart.apply(.{
        .baud_rate = baud_rate,
        .clock_config = rp2040.clock_config,
    });
    rp2040.uart.init_logger(uart);

    std.log.info("Hello, World!", .{});

    const bad_state = true;
    if (bad_state) {
        std.log.err("Something bad happened!", .{});
    }

    var counter: u8 = 255;
    counter += 1; // will overflow and panic
}
