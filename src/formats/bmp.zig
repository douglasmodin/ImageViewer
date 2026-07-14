const std = @import("std");
const Image = @import("../image.zig");

pub fn loadBMP(allocator: std.mem.Allocator, reader: *std.Io.Reader) !Image {
    // Unused for now
    var filesize: [1]u32 = undefined;
    var reserved: [1]u32 = undefined;
    var rasteroffset: [1]u32 = undefined;

    var infostruct_size: [1]u32 = undefined;

    var plains: [1]u16 = undefined;

    var bitcount: [1]u16 = undefined;

    var compression: [1]u32 = undefined;
    var compressed_image_size: [1]u32 = undefined;

    var x_pixels: [1]u32 = undefined;
    var y_pixels: [1]u32 = undefined;

    var colors_used: [1]u32 = undefined;
    var colors_important: [1]u32 = undefined;

    try reader.readSliceEndian(u32, filesize[0..], .little);
    try reader.readSliceEndian(u32, reserved[0..], .little);
    try reader.readSliceEndian(u32, rasteroffset[0..], .little);

    try reader.readSliceEndian(u32, infostruct_size[0..], .little);
    const width = try reader.takeInt(u32, .little);
    const height = try reader.takeInt(u32, .little);

    try reader.readSliceEndian(u16, plains[0..], .little);

    try reader.readSliceEndian(u16, bitcount[0..], .little);

    try reader.readSliceEndian(u32, compression[0..], .little);
    try reader.readSliceEndian(u32, compressed_image_size[0..], .little);

    try reader.readSliceEndian(u32, x_pixels[0..], .little);
    try reader.readSliceEndian(u32, y_pixels[0..], .little);

    try reader.readSliceEndian(u32, colors_used[0..], .little);
    try reader.readSliceEndian(u32, colors_important[0..], .little);

    var image: Image = .{ .width = width, .height = height, .original_format = .BMP };

    try image.pixels.ensureTotalCapacityPrecise(allocator, width * height);
    image.pixels.expandToCapacity();
    errdefer allocator.free(image.pixels.items);

    for (0..height) |j| {
        for (0..width) |i| {
            var pixel = Image.Pixel{};

            const row = height - j - 1;
            const col = i;

            pixel.b = try reader.takeByte();
            pixel.g = try reader.takeByte();
            pixel.r = try reader.takeByte();
            pixel.a = try reader.takeByte();
            image.pixels.items[col + (row * width)] = pixel;
        }
    }

    return image;
}
