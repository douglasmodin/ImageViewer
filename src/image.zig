const std = @import("std");

const bmp = @import("formats/bmp.zig");
const jpeg = @import("formats/jpeg.zig");
const png = @import("formats/png.zig");
const ppm = @import("formats/ppm.zig");
const qoi = @import("formats/qoi.zig");

const Image = @This();

width: u32 = 0,
height: u32 = 0,
colorspace: Colorspace = .sRGB,
original_format: Format = .UNKNOWN,
prefered_background: ?Pixel = null,

pixels: std.ArrayList(Pixel) = .empty,

const bmp_magic = .{ 'B', 'M' };
const jpeg_magic = .{ 0xFF, 0xD8 }; // SOT (Start of Image) // Not Implemented yet
const ppmp3_magic = .{ 'P', '3' };
const ppmp6_magic = .{ 'P', '6' };
const qoi_magic = .{ 'q', 'o', 'i', 'f' };
const png_magic = .{ 0x89, 0x50, 0x4E, 0x47 }; // .{'‰', 'P', 'N', 'G'} Symbol: '‰' (HEX 89) is in "Extended ASCII".
const riff_magic = .{ 'R', 'I', 'F', 'F' }; // Not Implemented yet

pub const Colorspace = enum {
    sRGB,
    RGBA,
};

pub const Pixel = packed struct(u32) {
    r: u8 = 0x00,
    g: u8 = 0x00,
    b: u8 = 0x00,
    a: u8 = 0xFF,
};

pub const Format = enum {
    UNKNOWN,
    BMP,
    JPEG,
    PNG,
    PPMP3,
    PPMP6,
    WEBP,
    QOI,
};

pub const ImageError = error{
    Invalid,
    UnsupportedFormat,
    UnknownFormat,
    NotImplementedYet,
};

pub fn load(io: std.Io, allocator: std.mem.Allocator, path: []const u8) !Image {
    const cwd = std.Io.Dir.cwd();

    const file = try cwd.openFile(io, path, .{ .mode = .read_only });
    defer file.close(io);

    var reader_buffer: [0xFFFF]u8 = undefined;

    var reader = file.reader(io, &reader_buffer);

    var magic: [4]u8 = undefined;

    try reader.interface.readSliceAll(magic[0..2]);

    if (std.mem.eql(u8, magic[0..2], &bmp_magic)) return try bmp.loadBMP(allocator, &reader.interface);
    if (std.mem.eql(u8, magic[0..2], &jpeg_magic)) return try jpeg.loadJPEG(allocator, &reader.interface);
    if (std.mem.eql(u8, magic[0..2], &ppmp3_magic)) return try ppm.loadPPMP3(allocator, &reader.interface);
    if (std.mem.eql(u8, magic[0..2], &ppmp6_magic)) return try ppm.loadPPMP6(allocator, &reader.interface);

    try reader.interface.readSliceAll(magic[2..]);

    if (std.mem.eql(u8, &magic, &qoi_magic)) return try qoi.loadQOI(allocator, &reader.interface);
    if (std.mem.eql(u8, &magic, &png_magic)) return try png.loadPNG(allocator, &reader.interface);
    if (std.mem.eql(u8, &magic, &riff_magic)) return ImageError.UnsupportedFormat;

    return ImageError.UnknownFormat;
}

pub fn loadFromMemory(allocator: std.mem.Allocator, bytes: []const u8) !Image {
    var reader = std.Io.Reader.fixed(bytes);

    var magic: [4]u8 = undefined;

    try reader.readSliceAll(magic[0..2]);

    if (std.mem.eql(u8, magic[0..2], &bmp_magic)) return try bmp.loadBMP(allocator, &reader);
    if (std.mem.eql(u8, magic[0..2], &jpeg_magic)) return jpeg.loadJPEG(allocator, &reader);
    if (std.mem.eql(u8, magic[0..2], &ppmp3_magic)) return try ppm.loadPPMP3(allocator, &reader);
    if (std.mem.eql(u8, magic[0..2], &ppmp6_magic)) return try ppm.loadPPMP6(allocator, &reader);

    try reader.readSliceAll(magic[2..]);

    if (std.mem.eql(u8, &magic, &qoi_magic)) return try qoi.loadQOI(allocator, &reader);
    if (std.mem.eql(u8, &magic, &png_magic)) return try png.loadPNG(allocator, &reader);
    if (std.mem.eql(u8, &magic, &riff_magic)) return error.UnsupportedFormatRIFF;

    return error.UnknownFormat;
}
