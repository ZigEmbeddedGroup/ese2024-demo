const std = @import("std");
const MicroZig = @import("microzig/build");
const rp2040 = @import("microzig/bsp/raspberrypi/rp2040");

pub fn build(b: *std.Build) void {
    const mz = MicroZig.init(b, .{});
    const optimize = b.standardOptimizeOption(.{});

    const mdf_dep = b.dependency("mdf", .{});

    const mdf_mod = mdf_dep.module("drivers");

    const firmware = mz.add_firmware(b, .{
        .name = "ese24-demo",
        .target = rp2040.boards.raspberrypi.pico,
        .optimize = optimize,
        .root_source_file = b.path("src/main.zig"),
    });
    firmware.add_app_import("drivers", mdf_mod, .{});

    mz.install_firmware(b, firmware, .{});

    mz.install_firmware(b, firmware, .{ .format = .elf });
}
