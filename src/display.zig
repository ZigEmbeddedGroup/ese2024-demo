const std = @import("std");
const microzig = @import("microzig");

pub const Framebuffer = microzig.drivers.display.ssd1306.Framebuffer;

const dri = @import("drivers.zig");

/// The splash bitmap we show before pressing the first button:
const splash_bitmap_data: *const [8 * 128]u8 = @embedFile("ese-splash.raw");

pub fn show_splash_screen() !void {
    try dri.display.write_full_display(splash_bitmap_data);
}

pub fn show_framebuffer(fb: *const Framebuffer) !void {
    try dri.display.write_full_display(fb.bit_stream());
}
