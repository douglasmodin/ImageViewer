const std = @import("std");
const Image = @import("../image.zig");

pub fn loadQOI(allocator: std.mem.Allocator, reader: *std.Io.Reader) !Image {
    const width = try reader.takeInt(u32, .big);
    const height = try reader.takeInt(u32, .big);

    // Unused for now
    var channels: [1]u8 = undefined;
    try reader.readSliceAll(channels[0..]);

    const colorspace = try reader.takeByte();

    var image: Image = .{ .width = width, .height = height, .original_format = .QOI };
    image.pixels = try .initCapacity(allocator, width * height);
    errdefer allocator.free(image.pixels.items);

    switch (colorspace) {
        0 => image.colorspace = .sRGB,
        1 => image.colorspace = .RGBA,
        else => return error.QOIInvalidColorspace,
    }

    var pixels_filled = false;

    var pixel: Image.Pixel = .{};

    var array: [64]Image.Pixel = [_]Image.Pixel{.{ .a = 0x00 }} ** 64;

    while (!pixels_filled) {
        const byte = try reader.takeByte();

        switch (byte) {
            0x00...0xFD => {
                const op: u2 = @intCast((byte & 0xC0) >> 6);
                switch (op) {
                    0b00 => { // Read Index
                        pixel = array[byte];
                    },
                    0b01 => { // Read Diff
                        const dr: i8 = @as(i8, @intCast(((byte & 0x30) >> 4))) - 2;
                        const dg: i8 = @as(i8, @intCast(((byte & 0x0C) >> 2))) - 2;
                        const db: i8 = @as(i8, @intCast(((byte & 0x03) >> 0))) - 2;

                        pixel.r = @bitCast(@as(i8, @bitCast(pixel.r)) +% dr);
                        pixel.g = @bitCast(@as(i8, @bitCast(pixel.g)) +% dg);
                        pixel.b = @bitCast(@as(i8, @bitCast(pixel.b)) +% db);
                    },
                    0b10 => { // Read Luma
                        const dg: i8 = @as(i8, @intCast((byte & 0x3F))) - 32;

                        const next_byte = try reader.takeByte();

                        const dr_dg: i8 = @as(i8, @intCast(((next_byte & 0xF0) >> 4))) - 8;
                        const db_dg: i8 = @as(i8, @intCast(((next_byte & 0x0F) >> 0))) - 8;

                        const dr = dg + dr_dg;
                        const db = dg + db_dg;

                        pixel.r = @bitCast(@as(i8, @bitCast(pixel.r)) +% dr);
                        pixel.g = @bitCast(@as(i8, @bitCast(pixel.g)) +% dg);
                        pixel.b = @bitCast(@as(i8, @bitCast(pixel.b)) +% db);
                    },
                    0b11 => { // Read Run
                        const len = byte & 0x3F;
                        if (len > 0xFC) return error.QOIInvalidRunLenght;

                        // We always append one pixel after the switch case, so here we only append len,
                        // even though the run should be interpreted as len + 1.
                        try image.pixels.appendNTimes(allocator, pixel, len);
                    },
                }
            },
            0xFE => { // Read RGB Value
                pixel.r = try reader.takeByte();
                pixel.g = try reader.takeByte();
                pixel.b = try reader.takeByte();
            },
            0xFF => { // Read RGBA Value
                pixel.r = try reader.takeByte();
                pixel.g = try reader.takeByte();
                pixel.b = try reader.takeByte();
                pixel.a = try reader.takeByte();
            },
        }

        try image.pixels.append(allocator, pixel);

        const index_position = (pixel.r *% 3 +% pixel.g *% 5 +% pixel.b *% 7 +% pixel.a *% 11) % 64;
        array[index_position] = pixel;

        if (image.pixels.items.len >= image.width * image.height) pixels_filled = true;
    }

    var end: [8]u8 = undefined;
    const expected_end: [8]u8 = .{ 0, 0, 0, 0, 0, 0, 0, 1 };

    try reader.readSliceAll(end[0..]);

    if (!std.mem.eql(
        u8,
        &end,
        &expected_end,
    )) return error.QOIInvalidFormat;

    return image;
}
