const std = @import("std");
const z2d = @import("z2d");

const display = @import("display.zig");

var working_memory: [128 * 1024]u8 = undefined;

const graphic = struct {
    const ang_base = -40 * std.math.rad_per_deg;
    const ang_range = 80 * std.math.rad_per_deg;
    const radius_digit = 35;
    const radius_mark_in = 38;
    const radius_mark_out = 45;
};

var static_framebuffer = display.Framebuffer.init(.black);
var dynamic_framebuffer = display.Framebuffer.init(.black);

pub fn prerender_graphics() !void {
    try render_content(&static_framebuffer, StaticGraphic{});
}

pub fn render_main_screen(level: u7) !void {
    try render_content(&dynamic_framebuffer, DynamicGraphic{
        .level = level,
    });

    overlay_framebuffer(&dynamic_framebuffer, &static_framebuffer);

    try display.show_framebuffer(&dynamic_framebuffer);
}

fn render_content(framebuffer: *display.Framebuffer, renderer: anytype) !void {
    var heap_allocator = std.heap.FixedBufferAllocator.init(&working_memory);
    errdefer |err| switch (err) {
        error.OutOfMemory => std.log.err("out of memory after {} bytes", .{heap_allocator.end_index}),
        else => {},
    };

    const allocator = heap_allocator.allocator();

    const surface = try z2d.Surface.init(
        .image_surface_alpha8,
        allocator,
        display.Framebuffer.width,
        display.Framebuffer.height,
    );
    defer surface.deinit();

    var context: z2d.Context = .{
        .surface = surface,
        .pattern = .{
            .opaque_pattern = .{
                .pixel = .{ .rgb = .{ .r = 0xFF, .g = 0xFF, .b = 0xFF } },
            },
        },
        .anti_aliasing_mode = .none,
        .line_width = 1.0,
    };

    try renderer.draw(allocator, &context);

    copy_surface_to_framebuffer(&surface, framebuffer);
}

const DynamicGraphic = struct {
    level: u7,

    pub fn draw(self: DynamicGraphic, alloc: std.mem.Allocator, context: *z2d.Context) !void {
        const float_level = @as(f32, @floatFromInt(self.level)) / std.math.maxInt(@TypeOf(self.level));

        var path = z2d.Path.init(alloc);
        defer path.deinit();

        {
            const ang = graphic.ang_base + float_level * graphic.ang_range;

            const dx = graphic.radius_digit * @sin(ang);
            const dy = graphic.radius_digit * @cos(ang);

            try path.moveTo(64, 54);
            try path.lineTo(64 + dx, 54 - dy);

            context.line_width = 1.0;
            try context.stroke(alloc, path);
            path.reset();
        }
    }
};

const StaticGraphic = struct {
    pub fn draw(self: StaticGraphic, alloc: std.mem.Allocator, context: *z2d.Context) !void {
        _ = self;

        var path = z2d.Path.init(alloc);
        defer path.deinit();

        // Paint gauge optics:
        // M 64 54
        // L 96 22
        // C 80 4 48 4 32 22
        // Z

        try path.moveTo(64, 54);
        try path.lineTo(96, 22);
        try path.curveTo(80, 4, 48, 4, 32, 22);
        try path.close();

        context.line_width = 2.0;
        try context.stroke(alloc, path);
        path.reset();

        // Paint gauge meter:
        // virtual arc:
        //  M 109 54
        //  a 1 1 0 0 0 -90 0 # means radius = 45

        for (0..10) |tick| {
            const perc: f32 = @as(f32, @floatFromInt(tick)) / 9;

            const ang = graphic.ang_base + perc * graphic.ang_range;

            const dx = @sin(ang);
            const dy = @cos(ang);

            try path.lineTo(64 + graphic.radius_mark_in * dx, 54 - graphic.radius_mark_in * dy);
            try path.lineTo(64 + graphic.radius_mark_out * dx, 54 - graphic.radius_mark_out * dy);

            context.line_width = 1.5;
            try context.stroke(alloc, path);
            path.reset();
        }
    }
};

/// Activates all pixels in `dst` which are active in `src`.
/// This way, a "max" operation is performed and afterwards, all pixels
/// that are active in either `src` or `dst` are active in `dst`.
fn overlay_framebuffer(dst: *display.Framebuffer, src: *const display.Framebuffer) void {
    for (&dst.pixel_data, &src.pixel_data) |*d, s| {
        d.* |= s;
    }
}

/// Copies a z2d surface to the display framebuffer.
fn copy_surface_to_framebuffer(surface: *const z2d.Surface, framebuffer: *display.Framebuffer) void {
    for (0..64) |y| {
        for (0..128) |x| {
            const pixel = surface.image_surface_alpha8.getPixel(@intCast(x), @intCast(y)) catch unreachable;

            framebuffer.set_pixel(
                @intCast(x),
                @intCast(y),
                if (pixel.alpha8.a > 0x80)
                    .white
                else
                    .black,
            );
        }
    }
}
