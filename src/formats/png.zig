const std = @import("std");
const Image = @import("../image.zig");

const PNG = struct {
    pub const ChunkType = enum {
        IHDR,
        PLTE,
        IDAT,
        IEND,
        // Chuncs we recognice, but do not parse as of now.
        // Might want to parse this in the future.
        cHRM,
        gAMA,
        iCCP,
        sBIT,
        sRGB,
        bKGD,
        hIST,
        tRNS,
        pHYs,
        sPLT,
        tIME,
        iTXt,
        tEXt,
        zTXt,
        PASS, // For chunks we do not want to parse, the parser skips these
    };

    pub fn strToChunkType(str: []u8) ChunkType {
        if (std.mem.eql(
            u8,
            str,
            "IHDR"[0..],
        )) {
            return .IHDR;
        } else if (std.mem.eql(
            u8,
            str,
            "PLTE"[0..],
        )) {
            return .PLTE;
        } else if (std.mem.eql(
            u8,
            str,
            "IDAT"[0..],
        )) {
            return .IDAT;
        } else if (std.mem.eql(
            u8,
            str,
            "IEND"[0..],
        )) {
            return .IEND;
        } else if (std.mem.eql(
            u8,
            str,
            "cHRM"[0..],
        )) {
            return .cHRM;
        } else if (std.mem.eql(
            u8,
            str,
            "gAMA"[0..],
        )) {
            return .gAMA;
        } else if (std.mem.eql(
            u8,
            str,
            "iCCP"[0..],
        )) {
            return .iCCP;
        } else if (std.mem.eql(
            u8,
            str,
            "sBIT"[0..],
        )) {
            return .sBIT;
        } else if (std.mem.eql(
            u8,
            str,
            "sRGB"[0..],
        )) {
            return .sRGB;
        } else if (std.mem.eql(
            u8,
            str,
            "bKGD"[0..],
        )) {
            return .bKGD;
        } else if (std.mem.eql(
            u8,
            str,
            "hIST"[0..],
        )) {
            return .hIST;
        } else if (std.mem.eql(
            u8,
            str,
            "tRNS"[0..],
        )) {
            return .tRNS;
        } else if (std.mem.eql(
            u8,
            str,
            "pHYs"[0..],
        )) {
            return .pHYs;
        } else if (std.mem.eql(
            u8,
            str,
            "sPLT"[0..],
        )) {
            return .sPLT;
        } else if (std.mem.eql(
            u8,
            str,
            "tIME"[0..],
        )) {
            return .tIME;
        } else if (std.mem.eql(
            u8,
            str,
            "iTXt"[0..],
        )) {
            return .iTXt;
        } else if (std.mem.eql(
            u8,
            str,
            "tEXt"[0..],
        )) {
            return .tEXt;
        } else if (std.mem.eql(
            u8,
            str,
            "zTXt"[0..],
        )) {
            return .zTXt;
        } else {
            return .PASS;
        }
    }
};

// https://www.w3.org/TR/2003/REC-PNG-20031110/#11IHDR
pub fn loadPNG(allocator: std.mem.Allocator, reader: *std.Io.Reader) !Image {
    var rest_of_magic: [4]u8 = undefined;
    const expected_magic: [4]u8 = .{ 0x0d, 0x0A, 0x1A, 0x0A };

    try reader.readSliceAll(rest_of_magic[0..]);

    var raw_data: std.ArrayList(u8) = .empty;
    defer raw_data.deinit(allocator);

    var palette: [256]Image.Pixel = .{Image.Pixel{}} ** 256;
    var palette_len: usize = 0;

    if (!std.mem.eql(
        u8,
        &rest_of_magic,
        &expected_magic,
    )) return Image.ImageError.Invalid;

    var width: u32 = 0;
    var height: u32 = 0;
    var bit_depth: u8 = 0;
    var color_type: u8 = 0;
    var samples_per_color: u8 = 4; // Default RGBA
    var compression_method: u8 = 0;
    var filter_method: u8 = 0;
    var interlace_method: u8 = 0;
    var preffered_background: ?Image.Pixel = null;

    var all_chunks_parsed = false;
    var total_chunks: usize = 0;

    while (!all_chunks_parsed) {
        total_chunks += 1;
        const chunk_data_lenght = try reader.takeInt(u32, .big);

        var chunk_type_raw: [4]u8 = undefined;

        try reader.readSliceAll(chunk_type_raw[0..]);

        const chunk_type = PNG.strToChunkType(&chunk_type_raw);

        //std.debug.print("ChunkType: {s}\n", .{chunk_type_raw});

        switch (chunk_type) {
            .IHDR => {
                if (chunk_data_lenght != 13) return Image.ImageError.Invalid;

                var chunk: [17]u8 = chunk_type_raw ++ .{0} ** 13;

                try reader.readSliceAll(chunk[4..]);

                const calc_checksum = std.hash.Crc32.hash(chunk[0..]);

                const read_checksum = try reader.takeInt(u32, .big);

                if (calc_checksum != read_checksum) return Image.ImageError.Invalid;

                width = std.mem.readVarInt(u32, chunk[4..8], .big);
                height = std.mem.readVarInt(u32, chunk[8..12], .big);
                bit_depth = chunk[12];

                if (bit_depth != 8) return Image.ImageError.NotImplementedYet;

                color_type = chunk[13];

                samples_per_color = smp: switch (color_type) {
                    0 => break :smp 1, // Grayscale
                    2 => break :smp 3, // RGB
                    3 => break :smp 1, // Palette
                    4 => break :smp 2, // Grayscale + alpha
                    6 => break :smp 4, // RGBA
                    else => return Image.ImageError.Invalid,
                };

                compression_method = chunk[14];

                if (compression_method != 0) return Image.ImageError.Invalid;

                filter_method = chunk[15];

                if (filter_method != 0) return Image.ImageError.Invalid;

                interlace_method = chunk[16];

                if (interlace_method != 0) return Image.ImageError.NotImplementedYet;

                raw_data = try .initCapacity(allocator, width * height * 4);
            },
            .PLTE => {
                if (chunk_data_lenght % 3 != 0) return Image.ImageError.Invalid;

                var crc = std.hash.Crc32.init();
                crc.update(chunk_type_raw[0..]);

                for (0..chunk_data_lenght / 3) |i| {
                    var palette_sample: [3]u8 = undefined;

                    try reader.readSliceAll(palette_sample[0..]);
                    crc.update(palette_sample[0..]);

                    palette[i].r = palette_sample[0];
                    palette[i].g = palette_sample[1];
                    palette[i].b = palette_sample[2];
                }

                palette_len = chunk_data_lenght / 3;

                const calc_checksum = crc.final();

                const read_checksum = try reader.takeInt(u32, .big);

                if (calc_checksum != read_checksum) return Image.ImageError.Invalid;
            },
            .IDAT => {
                var crc = std.hash.Crc32.init();
                crc.update(chunk_type_raw[0..]);

                var total_read: usize = 0;
                var read: usize = 0;
                const max_read: usize = 0xFFFF;

                while (total_read < chunk_data_lenght) {
                    read = @min(chunk_data_lenght - total_read, max_read);
                    total_read += read;

                    try reader.fill(read);

                    raw_data.appendSliceAssumeCapacity(reader.buffer[reader.seek .. reader.seek + read]); // CHANGED
                    crc.update(reader.buffer[reader.seek .. reader.seek + read]);
                    try reader.discardAll(read);
                }

                const calc_checksum = crc.final();

                const read_checksum = try reader.takeInt(u32, .big);

                if (calc_checksum != read_checksum) return Image.ImageError.Invalid;
            },
            .IEND => {
                if (chunk_data_lenght != 0) return Image.ImageError.Invalid;

                const read_checksum = try reader.takeInt(u32, .big);

                if (read_checksum != 0xAE426082) return Image.ImageError.Invalid;
                all_chunks_parsed = true;
            },
            .bKGD => {
                var crc = std.hash.Crc32.init();
                crc.update(chunk_type_raw[0..]);

                var bkgd_pixel = Image.Pixel{};

                switch (color_type) {
                    0, 4 => {
                        if (chunk_data_lenght != 2) return Image.ImageError.Invalid;
                        var val: [2]u8 = undefined;
                        try reader.readSliceAll(val[0..]);
                        crc.update(val[0..]);

                        bkgd_pixel.r = @truncate(std.mem.readVarInt(u16, val[0..], .big));
                        bkgd_pixel.g = @truncate(std.mem.readVarInt(u16, val[0..], .big));
                        bkgd_pixel.b = @truncate(std.mem.readVarInt(u16, val[0..], .big));
                    },
                    2, 6 => {
                        if (chunk_data_lenght != 6) return Image.ImageError.Invalid;
                        var rgb: [6]u8 = undefined;
                        try reader.readSliceAll(rgb[0..]);
                        crc.update(rgb[0..]);

                        bkgd_pixel.r = @truncate(std.mem.readVarInt(u16, rgb[0..2], .big));
                        bkgd_pixel.g = @truncate(std.mem.readVarInt(u16, rgb[2..4], .big));
                        bkgd_pixel.b = @truncate(std.mem.readVarInt(u16, rgb[4..6], .big));
                    },
                    3 => {
                        if (chunk_data_lenght != 1) return Image.ImageError.Invalid;

                        var sample: [1]u8 = undefined;
                        try reader.readSliceAll(sample[0..]);
                        crc.update(sample[0..]);

                        bkgd_pixel.r = palette[sample[0]].r;
                        bkgd_pixel.g = palette[sample[0]].g;
                        bkgd_pixel.b = palette[sample[0]].b;
                    },
                    else => return Image.ImageError.Invalid,
                }
                preffered_background = bkgd_pixel;

                const calc_checksum = crc.final();

                const read_checksum = try reader.takeInt(u32, .big);

                if (read_checksum != calc_checksum) return Image.ImageError.Invalid;
            },
            .cHRM, .gAMA, .iCCP, .sBIT, .sRGB, .hIST, .tRNS, .pHYs, .sPLT, .tIME, .iTXt, .tEXt, .zTXt, .PASS => {
                try reader.fill(chunk_data_lenght + 4);
                try reader.discardAll(chunk_data_lenght + 4);
            },
        }
    }

    var raw_data_reader = std.Io.Reader.fixed(raw_data.items);
    var writer = try std.Io.Writer.Allocating.initCapacity(allocator, width * height * samples_per_color + height);
    defer writer.deinit();

    var decompressor: std.compress.flate.Decompress = .init(&raw_data_reader, .zlib, &.{});

    _ = try decompressor.reader.streamRemaining(&writer.writer);

    var data = writer.written();

    var image: Image = .{ .width = width, .height = height, .original_format = .PNG, .prefered_background = preffered_background };
    image.pixels = try .initCapacity(allocator, width * height);
    errdefer allocator.free(image.pixels.items);

    for (0..height) |y| {
        const row_index = ((y * width) * samples_per_color) + y;
        const filter = data[row_index];

        for (0..width) |x| {
            for (0..samples_per_color) |i| {
                try filterByte(&data, (row_index + 1) + (x * samples_per_color) + i, filter, width, samples_per_color);
            }
        }
    }

    for (0..height) |y| {
        const row_index = ((y * width) * samples_per_color) + y;

        for (0..width) |x| {
            var pixel = Image.Pixel{};
            if (color_type == 0) {
                const val = data[(row_index + 1) + (x * samples_per_color) + 0];
                pixel.r = val;
                pixel.g = val;
                pixel.b = val;
            } else if (color_type == 2) {
                pixel.r = data[(row_index + 1) + (x * samples_per_color) + 0];
                pixel.g = data[(row_index + 1) + (x * samples_per_color) + 1];
                pixel.b = data[(row_index + 1) + (x * samples_per_color) + 2];
            } else if (color_type == 3) {
                pixel = palette[data[(row_index + 1) + (x * samples_per_color) + 0]];
            } else if (color_type == 4) {
                const val = data[(row_index + 1) + (x * samples_per_color) + 0];
                pixel.r = val;
                pixel.g = val;
                pixel.b = val;
                pixel.a = data[(row_index + 1) + (x * samples_per_color) + 1];
            } else if (color_type == 6) {
                pixel.r = data[(row_index + 1) + (x * samples_per_color) + 0];
                pixel.g = data[(row_index + 1) + (x * samples_per_color) + 1];
                pixel.b = data[(row_index + 1) + (x * samples_per_color) + 2];
                pixel.a = data[(row_index + 1) + (x * samples_per_color) + 3];
            } else {
                return Image.ImageError.Invalid;
            }
            image.pixels.appendAssumeCapacity(pixel);
        }
    }
    return image;
}

fn filterByte(data: *[]u8, index: usize, filter: u8, width: usize, n_samples: usize) !void {
    const n = index % ((width * n_samples) + 1);
    const m = @divFloor(index, (width * n_samples) + 1);

    switch (filter) {
        0 => {},
        1 => {
            if (n > n_samples) data.*[index] +%= data.*[index - n_samples];
        },
        2 => {
            if (m != 0) data.*[index] +%= data.*[index - (width * n_samples) - 1];
        },
        3 => {
            if (n <= n_samples and m == 0) return;

            var prev: u8 = 0;
            var up: u8 = 0;

            if (n > n_samples) prev = data.*[index - n_samples];
            if (m != 0) up = data.*[index - (width * n_samples) - 1];

            data.*[index] +%= avg(prev, up);
        },
        4 => {
            if (n <= n_samples and m == 0) return;

            var prev: u8 = 0;
            var up: u8 = 0;
            var prev_up: u8 = 0;

            if (n > n_samples) prev = data.*[index - n_samples];
            if (m != 0) up = data.*[index - (width * n_samples) - 1];
            if (n > n_samples and m != 0) prev_up = data.*[index - (width * n_samples) - 1 - n_samples];

            data.*[index] +%= paeth(prev, up, prev_up);
        },
        else => return error.UnknownFilter,
    }
}

fn avg(prev: u8, up: u8) u8 {
    const wide_prev = @as(i9, @intCast(prev));
    const wide_up = @as(i9, @intCast(up));
    const wide_div = @divFloor(wide_prev +% wide_up, 2);
    const res_signed = @as(i8, @truncate(wide_div));

    return @bitCast(res_signed);
}

fn paeth(a: u8, b: u8, c: u8) u8 {
    const p = @as(i16, a) + @as(i16, b) - @as(i16, c);
    const pa = @abs(p - a);
    const pb = @abs(p - b);
    const pc = @abs(p - c);

    if (pa <= pb and pa <= pc) {
        return a;
    } else if (pb <= pc) {
        return b;
    } else return c;
}
