const std = @import("std");
const microzig = @import("microzig");
const rp2040 = microzig.hal;

pub fn main() !void {
    const led_pin = rp2040.gpio.num(25);
    led_pin.set_function(.sio);
    led_pin.set_direction(.out);
    while (true) {
        led_pin.toggle();
        rp2040.time.sleep_ms(250);
    }
}
