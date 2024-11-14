const std = @import("std");
const microzig = @import("microzig");

const hw = @import("hardware.zig");

const drivers = microzig.drivers;
const rp2040 = microzig.hal;

// Driver configuration:

const SSD1306 = drivers.display.ssd1306.SSD1306_Generic(
    .{ .mode = .dynamic },
);

const RotaryEncoder = drivers.input.Rotary_Encoder(.{
    .Digital_IO = rp2040.drivers.GPIO_Device,
});

const DebouncedButton = drivers.input.Debounced_Button(.{
    .active_state = .low,
    .Digital_IO = rp2040.drivers.GPIO_Device,
});

pub var input_button: DebouncedButton = undefined;
pub var encoder: RotaryEncoder = undefined;
pub var display: SSD1306 = undefined;

var i2c_dev: rp2040.drivers.I2C_Device = undefined;
var spi_dev: rp2040.drivers.SPI_Device = undefined;
var spi_dc: rp2040.drivers.GPIO_Device = undefined;

pub fn setup() !void {
    std.log.info("set up rotary encoder...", .{});

    input_button = try DebouncedButton.init(rp2040.drivers.GPIO_Device{
        .pin = hw.enc_button,
    });

    encoder = try RotaryEncoder.init(
        rp2040.drivers.GPIO_Device{ .pin = hw.enc_a },
        rp2040.drivers.GPIO_Device{ .pin = hw.enc_b },
        .high,
    );

    std.log.info("set up display...", .{});

    i2c_dev = rp2040.drivers.I2C_Device{
        .bus = hw.i2c,
        .address = rp2040.i2c.Address.new(0b011_1100),
    };

    spi_dev = rp2040.drivers.SPI_Device.init(hw.spi, hw.spi_cs_pin, .{});
    spi_dc = rp2040.drivers.GPIO_Device.init(hw.spi_dc_pin);

    // Give the I/O pin some time to settle its state after enabling pull-up:
    rp2040.time.sleep_ms(5);

    std.log.info("initialize display driver...", .{});

    // We can use an external button to switch between an I²C or SPI display:
    display = switch (hw.get_display_mode_select()) {
        .spi => try SSD1306.init(.{
            .spi_4wire = .{
                .device = spi_dev.datagram_device(),
                .dc_pin = spi_dc.digital_io(),
            },
        }),
        .i2c => try SSD1306.init(.{
            .i2c = .{ .device = i2c_dev.datagram_device() },
        }),
    };
}
