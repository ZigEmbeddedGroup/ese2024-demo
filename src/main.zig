// Module imports:
const std = @import("std");
const microzig = @import("microzig");

// Other files of the project:
const hw = @import("hardware.zig");
const dri = @import("drivers.zig");
const display = @import("display.zig");
const graphics = @import("graphics.zig");

// MicroZig configuration:
pub fn panic(message: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    std.log.err("panic: {s}", .{message});
    @breakpoint();
    while (true) {}
}

pub const microzig_options = .{
    .log_level = .debug,
    .logFn = microzig.hal.uart.logFn,
};

// Application:

const max_display_refresh_period_us = 50 * std.time.us_per_ms; // 20 Hz

pub fn main() !void {
    errdefer |err| std.log.err(
        "application crashed: {s}",
        .{@errorName(err)},
    );

    try hw.setup();

    try dri.setup();

    // Before we initialize the display, let's render the splash screen,
    // so we hide the render time:
    try display.show_splash_screen();

    try graphics.prerender_graphics();

    std.log.info("wait for button press...", .{});

    // wait for user to release the button:
    while (try dri.input_button.poll() != .released) {
        //
    }

    std.log.info("start application loop.", .{});

    var current_level: u7 = 64;
    var displayed_level: u7 = current_level;
    var last_update_time = microzig.hal.time.get_time_since_boot();

    try graphics.render_main_screen(current_level);

    while (true) {
        const rot_event = try dri.encoder.poll();
        switch (rot_event) {
            .idle => {},
            .increment => {
                current_level +|= 1;
                std.log.info("encoder: increment to {}", .{current_level});
            },
            .decrement => {
                current_level -|= 1;
                std.log.info("encoder: decrement to {}", .{current_level});
            },
            .@"error" => {},
        }

        const btn_event = try dri.input_button.poll();
        switch (btn_event) {
            .idle => {},
            .pressed => {
                current_level = 64;
                std.log.info("button: reset to {}", .{current_level});
            },
            .released => {},
        }

        if (displayed_level != current_level) {
            const now = microzig.hal.time.get_time_since_boot();

            if (now.diff(last_update_time).to_us() >= max_display_refresh_period_us) {
                try graphics.render_main_screen(current_level);
                displayed_level = current_level;
                last_update_time = now;
            }
        }
    }
}
