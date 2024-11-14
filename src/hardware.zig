const std = @import("std");
const microzig = @import("microzig");

const rp2040 = microzig.hal;

const baud_rate = 115200;

// Hardware allocation:

pub const uart = rp2040.uart.instance.num(0);
pub const i2c = rp2040.i2c.instance.num(0);
pub const spi = rp2040.spi.instance.num(0);

const led = rp2040.gpio.num(25);

const uart_tx_pin = rp2040.gpio.num(0);
const uart_rx_pin = rp2040.gpio.num(1);

const i2c_scl_pin = rp2040.gpio.num(17);
const i2c_sda_pin = rp2040.gpio.num(16);

const mode_switch_pin = rp2040.gpio.num(15);

pub const enc_button = rp2040.gpio.num(18);
pub const enc_a = rp2040.gpio.num(19);
pub const enc_b = rp2040.gpio.num(20);

const spi_sck_pin = rp2040.gpio.num(2);
const spi_tx_pin = rp2040.gpio.num(3);
// const spi_rx_pin = gpio.num(4);
pub const spi_cs_pin = rp2040.gpio.num(5);
pub const spi_dc_pin = rp2040.gpio.num(6);

pub fn setup() !void {
    uart_tx_pin.set_function(.uart);
    uart_rx_pin.set_function(.uart);

    i2c_scl_pin.set_function(.i2c);
    i2c_sda_pin.set_function(.i2c);

    enc_button.set_function(.sio);
    enc_a.set_function(.sio);
    enc_b.set_function(.sio);

    spi_sck_pin.set_function(.spi);
    spi_tx_pin.set_function(.spi);
    spi_cs_pin.set_function(.sio);
    spi_dc_pin.set_function(.sio);

    mode_switch_pin.set_function(.sio);
    mode_switch_pin.set_direction(.in);
    mode_switch_pin.set_pull(.up);

    spi_cs_pin.set_direction(.out);
    spi_cs_pin.put(1);

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

    std.log.info("set up spi...", .{});
    try spi.apply(.{
        .clock_config = rp2040.clock_config,
        .baud_rate = 1_000_000,
        .frame_format = .{
            .motorola = .{
                .clock_polarity = .default_high,
                .clock_phase = .second_edge,
            },
        },
    });
}

pub const DisplayMode = enum {
    i2c,
    spi,
};

pub fn get_display_mode_select() DisplayMode {
    const mode_select = mode_switch_pin.read();
    return switch (mode_select) {
        0 => .spi,
        1 => .i2c,
    };
}
