const std = @import("std");
const Image = @import("../image.zig");

pub fn loadPPMP6(allocator: std.mem.Allocator, reader: *std.Io.Reader) !Image {
    const current_byte = try reader.takeByte();

    if (!std.ascii.isWhitespace(current_byte)) return error.PPM6InvalidMagic;

    const width = @as(u32, @intCast(getNextNumber(reader) catch return error.PPMP3InvalidWidth));

    const height = @as(u32, @intCast(getNextNumber(reader) catch return error.PPMP3InvalidHeight));

    // Maximum value per channel (Bit depth)
    _ = @as(u8, @intCast(getNextNumber(reader) catch return error.PPMP3InvalidHeight));

    var image = Image{ .width = width, .height = height, .original_format = .PPMP6 };
    image.pixels = try .initCapacity(allocator, width * height);
    errdefer allocator.free(image.pixels.items);

    for (0..width * height) |_| {
        var pixel: Image.Pixel = .{};

        pixel.r = try reader.takeByte();
        pixel.g = try reader.takeByte();
        pixel.b = try reader.takeByte();

        image.pixels.appendAssumeCapacity(pixel);
    }

    return image;
}

pub fn loadPPMP3(allocator: std.mem.Allocator, reader: *std.Io.Reader) !Image {
    const current_byte = try reader.takeByte();

    if (!std.ascii.isWhitespace(current_byte)) return error.PPM3InvalidMagic;

    const width = @as(u32, @intCast(getNextNumber(reader) catch return error.PPMP3InvalidWidth));

    const height = @as(u32, @intCast(getNextNumber(reader) catch return error.PPMP3InvalidWidth));

    // Maximum value per channel (Bit depth)
    _ = @as(u8, @intCast(getNextNumber(reader) catch return error.PPMP3InvalidWidth));

    var image = Image{ .width = width, .height = height, .original_format = .PPMP3 };
    image.pixels = try .initCapacity(allocator, width * height);
    errdefer image.pixels.deinit(allocator);

    for (0..width * height) |_| {
        var pixel: Image.Pixel = .{};

        pixel.r = @as(u8, @intCast(try getNextNumber(reader)));
        pixel.g = @as(u8, @intCast(try getNextNumber(reader)));
        pixel.b = @as(u8, @intCast(try getNextNumber(reader)));

        image.pixels.appendAssumeCapacity(pixel);
    }
    return image;
}

fn getNextNumber(reader: *std.Io.Reader) !usize {
    var number: usize = 0;
    var number_began: bool = false;
    var number_done: bool = false;

    var current_byte: u8 = 0;

    while (!number_done) {
        current_byte = try reader.takeByte();

        if (!number_began and std.ascii.isWhitespace(current_byte)) {
            continue;
        } else if (std.ascii.isWhitespace(current_byte)) {
            number_done = true;
            break;
        }

        switch (current_byte) {
            '0'...'9' => {
                number_began = true;
                number *= 10;
                number += current_byte - '0';
            },
            else => return error.PPMInvalidNumber,
        }
    }

    return number;
}
