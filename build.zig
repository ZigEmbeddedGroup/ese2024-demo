const std = @import("std");
const MicroZig = @import("microzig/build");
const rp2040 = @import("microzig/bsp/raspberrypi/rp2040");

pub fn build(b: *std.Build) void {
    const mz = MicroZig.init(b, .{});
    const optimize = b.standardOptimizeOption(.{});

    const mdf_dep = b.dependency("mdf", .{});

    const mdf_mod = mdf_dep.module("drivers");

    const convert_bitmap_tool = b.addExecutable(.{
        .name = "convert-bitmap",
        .target = b.host,
        .optimize = .Debug,
        .root_source_file = b.path("tools/convert-bitmap.zig"),
    });

    const convert_bitmap_run = b.addRunArtifact(convert_bitmap_tool);
    convert_bitmap_run.addFileArg(b.path("assets/ese.pbm"));
    const raw_bitmap_file = convert_bitmap_run.addOutputFileArg("ese.raw");

    const raw_bitmap_mod = b.createModule(.{
        .root_source_file = raw_bitmap_file,
    });

    const firmware = mz.add_firmware(b, .{
        .name = "ese24-demo",
        .target = rp2040.boards.raspberrypi.pico,
        .optimize = optimize,
        .root_source_file = b.path("src/main.zig"),
    });
    firmware.add_app_import("drivers", mdf_mod, .{});
    firmware.add_app_import("ese-splash.raw", raw_bitmap_mod, .{});

    mz.install_firmware(b, firmware, .{});

    mz.install_firmware(b, firmware, .{ .format = .elf });
}
