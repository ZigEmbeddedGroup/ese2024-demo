//!
//! This example blinks the LED attached to GPIO25 on the Pi Pico.
//!

const std = @import("std");
const microzig = @import("microzig");
const rp2040 = microzig.hal;

const led_pin = rp2040.gpio.num(25);

pub fn main() !void {
    led_pin.set_function(.sio); // Set to "GPIO"
    led_pin.set_direction(.output); // Set as output

    var state: u1 = 0;

    while (true) {
        // after the loop, invert the state:
        defer state = 1 - state;

        // Write the GPIO pin:
        led_pin.put(state);

        // Use the pre-configured timer to sleep:
        rp2040.time.sleep_ms(250);
    }
}
