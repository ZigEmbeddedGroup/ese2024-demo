const std = @import("std");

pub fn main() !u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const argv = try std.process.argsAlloc(arena.allocator());
    defer std.process.argsFree(arena.allocator(), argv);

    if (argv.len != 3) {
        std.debug.print("usage: convert-bitmap <pbm file> <raw output bitmap>\n", .{});
        return 1;
    }

    var linear_bitmap: [64][128]u1 = undefined;

    {
        var pbm_file = try std.fs.cwd().openFile(argv[1], .{});
        defer pbm_file.close();

        var buffered_reader = std.io.bufferedReader(pbm_file.reader());

        const reader = buffered_reader.reader();

        var first_line_buffer: [64]u8 = undefined;
        const first_line = blk: {
            var fbs = std.io.fixedBufferStream(&first_line_buffer);
            try reader.streamUntilDelimiter(fbs.writer(), '\n', null);
            break :blk fbs.getWritten();
        };

        var iter = std.mem.tokenizeScalar(u8, first_line, ' ');

        const file_type = iter.next() orelse return error.BadFile;
        if (!std.mem.eql(u8, file_type, "P1"))
            return error.BadFile;

        const width_str = iter.next() orelse return error.BadFile;
        const height_str = iter.next() orelse return error.BadFile;

        const width: u32 = try std.fmt.parseInt(u32, width_str, 10);
        const height: u32 = try std.fmt.parseInt(u32, height_str, 10);

        if (width != 128 or height != 64)
            return error.BadDimension;

        for (&linear_bitmap) |*scanline| {
            for (scanline) |*pixel| {
                const bit_data = while (true) {
                    const byte = try reader.readByte();
                    if (byte == '1' or byte == '0')
                        break byte;
                };

                pixel.* = @intFromBool(bit_data == '1');
            }
        }
    }

    var display_bitmap = std.mem.zeroes([64 / 8][128]u8);
    {
        for (linear_bitmap, 0..) |scanline, y| {
            for (scanline, 0..) |pixel, x| {
                const col = x;
                const row = y / 8;
                const bit = y % 8;

                display_bitmap[row][col] |= @as(u8, pixel) << @truncate(bit);
            }
        }
    }

    {
        var output = try std.fs.cwd().createFile(argv[2], .{});
        defer output.close();

        try output.writeAll(std.mem.asBytes(&display_bitmap));
    }

    return 0;
}
