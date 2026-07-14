const std = @import("std");
const Image = @import("../image.zig");

const JPEGMarker = enum(u8) {
    NONE = 0x00,

    SOF0 = 0xC0, // Start of Frame (Baseline JPEG) (Image metadata, width, height etc.).
    SOF1 = 0xC1, // Start of Frame (Extended Sequential DCT).
    SOF2 = 0xC2, // Start of Frame (Progressive DCT).
    SOF3 = 0xC3, // Start of Frame (Lossless Sequential).
    DHT = 0xC4, // Define Huffman table.
    SOF5 = 0xC5, // Start of Frame (Differential Sequential DCT).
    SOF6 = 0xC6, // Start of Frame (Differential Prograssive DCT).
    SOF7 = 0xC7, // Start of Frame (Differential Lossless DCT).
    JPG = 0xC8, // JPEG extensions
    SOF9 = 0xC9,
    SOF10 = 0xCA,
    SOF11 = 0xCB,
    DAC = 0xCC,
    SOF13 = 0xCD,
    SOF14 = 0xCE,
    SOF15 = 0xCF,

    RST0 = 0xD0,
    RST1 = 0xD1,
    RST2 = 0xD2,
    RST3 = 0xD3,
    RST4 = 0xD4,
    RST5 = 0xD5,
    RST6 = 0xD6,
    RST7 = 0xD7,
    SOI = 0xD8, // Start of Image.
    EOI = 0xD9, // End of Image.
    SOS = 0xDA, //Start of scan. (Start of image data)
    DQT = 0xDB, // Define Quantization table.
    DNL = 0xDC, // Define number lines (not common).
    DRI = 0xDD, // Define restart intervall.
    DHP = 0xDE, // Define hirarchial prograssion (not common)
    EXP = 0xDF, // Expand reference component (not common)

    APP0 = 0xE0, // Application 0 (JFIF).
    APP1 = 0xE1, // Application 1 (EXIF).
    APP2 = 0xE2, // Application 2
    APP3 = 0xE3, // Application 3
    APP4 = 0xE4, // Application 4
    APP5 = 0xE5, // Application 5
    APP6 = 0xE6, // Application 6
    APP7 = 0xE7, // Application 7
    APP8 = 0xE8, // Application 8
    APP9 = 0xE9, // Application 9
    APP10 = 0xEA, // Application 10
    APP11 = 0xEB, // Application 11
    APP12 = 0xEC, // Application 12
    APP13 = 0xED, // Application 13
    APP14 = 0xEE, // Application 14
    APP15 = 0xEF, // Application 15

    JPG0 = 0xF0,
    JPG2 = 0xF1,
    JPG3 = 0xF2,
    JPG4 = 0xF3,
    JPG5 = 0xF4,
    JPG6 = 0xF6,
    JPG7 = 0xF7,
    JPG8 = 0xF8,
    JPG9 = 0xF9,
    JPG10 = 0xFA,
    JPG11 = 0xFB,
    JPG12 = 0xFC,
    JPG13 = 0xFD,
    JPG14 = 0xFE,

    START = 0xFF,

    pub fn as(byte: u8) @This() {
        return if (byte >= 0xC0) @enumFromInt(byte) else .NONE;
    }
};

const BitReader = struct {
    byte: usize,
    bit: u8,
    data: *[]u8,

    pub fn init(data: *[]u8) @This() {
        return .{
            .bit = 0,
            .byte = 0,
            .data = data,
        };
    }

    pub fn next(self: *@This()) !u8 {
        if (self.data.len <= self.byte) return error.EndOfData;
        const bit = (self.data.*[self.byte] >> @intCast(7 - self.bit)) & 1;
        self.bit += 1;
        if (self.bit > 7) {
            self.bit = 0;
            self.byte += 1;
        }
        return bit;
    }

    pub fn nextN(self: *@This(), lenght: usize) !usize {
        var bits: usize = 0;
        for (0..lenght) |_| {
            const bit: usize = @as(usize, @intCast(try self.next()));
            bits = (bits << 1) | bit;
        }
        return bits;
    }

    pub fn byteAlign(self: *@This()) !void {
        if (self.byte >= self.data.len) return error.EndOfData;

        if (self.bit != 0) {
            self.byte += 1;
            self.bit = 0;
        }
    }
};

const HuffmanTable = struct {
    offsets: [17]usize = .{0} ** 17,
    symbols: [162]u8 = .{0} ** 162,
    codes: [162]usize = .{0} ** 162,
    set: bool = false,
};

const Component = struct {
    id: u8 = 0,
    sampling_factor_horizontal: u8 = 1,
    sampling_factor_vertical: u8 = 1,
    quant_id: u8 = 0,
    dc_id: u8 = 0,
    ac_id: u8 = 0,
    used: bool = false,
};

const Block = union {
    ycbcr: struct { y: [64]isize, cb: [64]isize, cr: [64]isize },
    arr: [3][64]isize,
};

const DiscreteCosineTransform = struct {
    pub const m0 = 2.0 * @cos(1.0 / 16.0 * 2.0 * std.math.pi);
    pub const m1 = 2.0 * @cos(2.0 / 16.0 * 2.0 * std.math.pi);
    pub const m2 = m0 - m5;
    pub const m3 = 2.0 * @cos(2.0 / 16.0 * 2.0 * std.math.pi);
    pub const m4 = m0 + m5;
    pub const m5 = 2.0 * @cos(3.0 / 16.0 * 2.0 * std.math.pi);

    pub const s0 = @cos(0.0 / 16.0 * std.math.pi) / @sqrt(8.0);
    pub const s1 = @cos(1.0 / 16.0 * std.math.pi) / 2.0;
    pub const s2 = @cos(2.0 / 16.0 * std.math.pi) / 2.0;
    pub const s3 = @cos(3.0 / 16.0 * std.math.pi) / 2.0;
    pub const s4 = @cos(4.0 / 16.0 * std.math.pi) / 2.0;
    pub const s5 = @cos(5.0 / 16.0 * std.math.pi) / 2.0;
    pub const s6 = @cos(6.0 / 16.0 * std.math.pi) / 2.0;
    pub const s7 = @cos(7.0 / 16.0 * std.math.pi) / 2.0;

    pub fn inverse(slice: *[64]isize) void {
        var result: [64]f64 = .{0} ** 64;

        for (slice, 0..) |item, i| {
            result[i] = @as(f64, @floatFromInt(item));
        }

        for (0..8) |i| {
            const g0 = result[0 * 8 + i] * s0;
            const g1 = result[4 * 8 + i] * s4;
            const g2 = result[2 * 8 + i] * s2;
            const g3 = result[6 * 8 + i] * s6;
            const g4 = result[5 * 8 + i] * s5;
            const g5 = result[1 * 8 + i] * s1;
            const g6 = result[7 * 8 + i] * s7;
            const g7 = result[3 * 8 + i] * s3;

            const f0 = g0;
            const f1 = g1;
            const f2 = g2;
            const f3 = g3;
            const f4 = g4 - g7;
            const f5 = g5 + g6;
            const f6 = g5 - g6;
            const f7 = g4 + g7;

            const e0 = f0;
            const e1 = f1;
            const e2 = f2 - f3;
            const e3 = f2 + f3;
            const e4 = f4;
            const e5 = f5 - f7;
            const e6 = f6;
            const e7 = f5 + f7;
            const e8 = f4 + f6;

            const d0 = e0;
            const d1 = e1;
            const d2 = e2 * m1;
            const d3 = e3;
            const d4 = e4 * m2;
            const d5 = e5 * m3;
            const d6 = e6 * m4;
            const d7 = e7;
            const d8 = e8 * m5;

            const c0 = d0 + d1;
            const c1 = d0 - d1;
            const c2 = d2 - d3;
            const c3 = d3;
            const c4 = d4 + d8;
            const c5 = d5 + d7;
            const c6 = d6 - d8;
            const c7 = d7;
            const c8 = c5 - c6;

            const b0 = c0 + c3;
            const b1 = c1 + c2;
            const b2 = c1 - c2;
            const b3 = c0 - c3;
            const b4 = c4 - c8;
            const b5 = c8;
            const b6 = c6 - c7;
            const b7 = c7;

            result[0 * 8 + i] = b0 + b7;
            result[1 * 8 + i] = b1 + b6;
            result[2 * 8 + i] = b2 + b5;
            result[3 * 8 + i] = b3 + b4;
            result[4 * 8 + i] = b3 - b4;
            result[5 * 8 + i] = b2 - b5;
            result[6 * 8 + i] = b1 - b6;
            result[7 * 8 + i] = b0 - b7;
        }

        for (0..8) |i| {
            const g0 = result[i * 8 + 0] * s0;
            const g1 = result[i * 8 + 4] * s4;
            const g2 = result[i * 8 + 2] * s2;
            const g3 = result[i * 8 + 6] * s6;
            const g4 = result[i * 8 + 5] * s5;
            const g5 = result[i * 8 + 1] * s1;
            const g6 = result[i * 8 + 7] * s7;
            const g7 = result[i * 8 + 3] * s3;

            const f0 = g0;
            const f1 = g1;
            const f2 = g2;
            const f3 = g3;
            const f4 = g4 - g7;
            const f5 = g5 + g6;
            const f6 = g5 - g6;
            const f7 = g4 + g7;

            const e0 = f0;
            const e1 = f1;
            const e2 = f2 - f3;
            const e3 = f2 + f3;
            const e4 = f4;
            const e5 = f5 - f7;
            const e6 = f6;
            const e7 = f5 + f7;
            const e8 = f4 + f6;

            const d0 = e0;
            const d1 = e1;
            const d2 = e2 * m1;
            const d3 = e3;
            const d4 = e4 * m2;
            const d5 = e5 * m3;
            const d6 = e6 * m4;
            const d7 = e7;
            const d8 = e8 * m5;

            const c0 = d0 + d1;
            const c1 = d0 - d1;
            const c2 = d2 - d3;
            const c3 = d3;
            const c4 = d4 + d8;
            const c5 = d5 + d7;
            const c6 = d6 - d8;
            const c7 = d7;
            const c8 = c5 - c6;

            const b0 = c0 + c3;
            const b1 = c1 + c2;
            const b2 = c1 - c2;
            const b3 = c0 - c3;
            const b4 = c4 - c8;
            const b5 = c8;
            const b6 = c6 - c7;
            const b7 = c7;

            result[i * 8 + 0] = b0 + b7;
            result[i * 8 + 1] = b1 + b6;
            result[i * 8 + 2] = b2 + b5;
            result[i * 8 + 3] = b3 + b4;
            result[i * 8 + 4] = b3 - b4;
            result[i * 8 + 5] = b2 - b5;
            result[i * 8 + 6] = b1 - b6;
            result[i * 8 + 7] = b0 - b7;
        }
        for (result, 0..) |item, i| {
            slice[i] = @as(isize, @intFromFloat(item));
        }
    }

    pub fn slowInv(slice: *[64]isize) void {
        var result: [64]isize = .{0} ** 64;
        for (0..8) |y| {
            for (0..8) |x| {
                var sum: f64 = 0;
                for (0..8) |i| {
                    for (0..8) |j| {
                        const ci: f64 = if (i == 0) 1.0 / @sqrt(2.0) else 1.0;
                        const cj: f64 = if (j == 0) 1.0 / @sqrt(2.0) else 1.0;
                        sum += ci * cj * @as(f64, @floatFromInt(slice[i * 8 + j])) * @cos((2.0 * @as(f64, @floatFromInt(x)) + 1.0) * @as(f64, @floatFromInt(j)) * (std.math.pi / 16.0)) * @cos((2.0 * @as(f64, @floatFromInt(y)) + 1.0) * @as(f64, @floatFromInt(i)) * (std.math.pi / 16.0));
                    }
                }
                sum /= 4;
                result[y * 8 + x] = @intFromFloat(sum);
            }
        }

        for (result, 0..) |item, i| {
            slice[i] = item;
        }
    }
};

pub fn loadJPEG(allocator: std.mem.Allocator, reader: *std.Io.Reader) !Image {

    // [0,  1,   2,  3,  4,  5,  6,  7]
    // [8,  9,  10, 11, 12, 13, 14, 15]
    // [16, 17, 18, 19, 20, 21, 22, 23]
    // [24, 25, 26, 27, 28, 29, 30, 31]
    // [32, 33, 34, 35, 36, 37, 38, 39]
    // [40, 41, 42, 43, 44, 45, 46, 47]
    // [48, 49, 50, 51, 52, 53, 54, 55]
    // [56, 57, 58, 59, 60, 61, 62, 63]

    const zigZagTable: [64]u8 = .{ 0, 1, 8, 16, 9, 2, 3, 10, 17, 24, 32, 25, 18, 11, 4, 5, 12, 19, 26, 33, 40, 48, 41, 34, 27, 20, 13, 6, 7, 14, 21, 28, 35, 42, 49, 56, 57, 50, 43, 36, 29, 22, 15, 23, 30, 37, 44, 51, 58, 59, 52, 45, 38, 31, 39, 46, 53, 60, 61, 54, 47, 55, 62, 63 };

    var quantization_tables: [4][64]u16 = undefined;

    var component_specs: [3]Component = .{Component{}} ** 3;
    var component_zero_based: bool = false;

    var dc_huffman_tables: [4]HuffmanTable = undefined;
    var ac_huffman_tables: [4]HuffmanTable = undefined;

    var dc_reset_markers: std.ArrayList(usize) = .empty;
    defer if (dc_reset_markers.items.len > 0) dc_reset_markers.deinit(allocator);

    var dc_reset_interval: u16 = 0;

    var width: usize = 0;
    var height: usize = 0;
    var components: usize = 0;
    var block_width: usize = 0;
    var block_height: usize = 0;
    var block_width_real: usize = 0;
    var block_height_real: usize = 0;
    var sampling_factor_horizontal: usize = 0;
    var sampling_factor_vertical: usize = 0;
    var start_of_selection: u8 = 0;
    var end_of_selection: u8 = 0;
    var successive_approximation_high: u8 = 0;
    var successive_approximation_low: u8 = 0;

    var app0_encountered: bool = false;
    var sof_encountered: bool = false;

    var current_byte_or_err = reader.takeByte();

    while (current_byte_or_err != error.EndOfStream) {
        var current_byte = try current_byte_or_err;
        if (current_byte == @intFromEnum(JPEGMarker.START)) {
            current_byte = try reader.takeByte();

            switch (JPEGMarker.as(current_byte)) {
                .APP0, .APP1, .APP2, .APP14 => {
                    app0_encountered = true;
                    const len = try reader.takeInt(u16, .big);
                    for (0..len - 2) |_| {
                        _ = try reader.takeByte();
                    }
                },
                .DQT => {
                    var len = try reader.takeInt(i16, .big);
                    len -= 2;

                    while (len > 0) {
                        const table_info = try reader.takeByte();
                        len -= 1;

                        const precision = (table_info >> 4);
                        const id = (table_info & 0x0F);

                        for (0..64) |i| {
                            if (precision == 0) {
                                quantization_tables[id][zigZagTable[i]] = try reader.takeByte();
                                len -= 1;
                            } else {
                                quantization_tables[id][zigZagTable[i]] = try reader.takeInt(u16, .big);
                                len -= 2;
                            }
                        }
                    }
                    if (len != 0) return error.JPEGFaultyQTable;
                },
                .SOF0 => {
                    sof_encountered = true;
                    _ = try reader.takeInt(u16, .big);

                    const precision = try reader.takeByte();

                    if (precision != 8) return error.JPEGUnsupportedBitsPerSample;

                    height = @as(usize, try reader.takeInt(u16, .big));
                    width = @as(usize, try reader.takeInt(u16, .big));

                    block_width = @divFloor(width + 7, 8);
                    block_height = @divFloor(height + 7, 8);
                    block_width_real = block_width;
                    block_height_real = block_height;

                    components = try reader.takeByte();

                    if (components != 3) return error.JPEGUnsupportedComponentSize;

                    for (0..components) |i| {
                        var id = try reader.takeByte();

                        // Fix for images that use zero based component id's.
                        // This is not really allowed by the JPEG standard,
                        // but some encoders seem to do this anyway.
                        if (id == 0) component_zero_based = true;
                        if (component_zero_based) id += 1;

                        component_specs[i].id = id;

                        const sampling_factor = try reader.takeByte();

                        component_specs[i].sampling_factor_horizontal = sampling_factor >> 4;
                        component_specs[i].sampling_factor_vertical = sampling_factor & 0x0F;

                        // Y component
                        if (id == 1) {
                            if ((component_specs[i].sampling_factor_horizontal != 1 and
                                component_specs[i].sampling_factor_horizontal != 2) or
                                (component_specs[i].sampling_factor_vertical != 1 and
                                    component_specs[i].sampling_factor_vertical != 2))
                            {
                                return error.JPEGSubSamplingTypeNotSupported;
                            }

                            if (component_specs[i].sampling_factor_horizontal == 2 and block_width % 2 != 0) block_width_real += 1;
                            if (component_specs[i].sampling_factor_vertical == 2 and block_height % 2 != 0) block_height_real += 1;

                            sampling_factor_horizontal = component_specs[i].sampling_factor_horizontal;
                            sampling_factor_vertical = component_specs[i].sampling_factor_vertical;

                            // Color Component
                        } else {
                            if (component_specs[i].sampling_factor_horizontal != 1 or
                                component_specs[i].sampling_factor_vertical != 1)
                            {
                                return error.JPEGSubSamplingTypeNotSupported;
                            }
                        }

                        component_specs[i].quant_id = try reader.takeByte();
                    }
                },
                .DHT => {
                    var len = try reader.takeInt(i16, .big);
                    len -= 2;

                    while (len > 0) {
                        const table_info = try reader.takeByte();
                        const class = (table_info >> 4);
                        const id = table_info & 0x0F;

                        var table = HuffmanTable{ .set = true };

                        var all_symbols: usize = 0;

                        for (1..17) |i| {
                            all_symbols += try reader.takeByte();
                            table.offsets[i] = all_symbols;
                        }

                        if (all_symbols > 162) {
                            std.debug.print("{d}\n", .{all_symbols});
                            return error.JPEGInvalidHuffmanSymbolSize;
                        }

                        for (0..all_symbols) |i| {
                            table.symbols[i] = try reader.takeByte();
                        }
                        len -= 17 + @as(i16, @intCast(all_symbols));

                        if (class == 0) {
                            dc_huffman_tables[id] = table;
                        } else if (class == 1) {
                            ac_huffman_tables[id] = table;
                        }
                    }
                    if (len != 0) return error.JPEGInvalidHuffmanSize;
                },
                .DRI => {
                    const len = try reader.takeInt(u16, .big);

                    if (len != 4) return error.JPEGInvalidResetInterval;

                    dc_reset_interval = try reader.takeInt(u16, .big);
                },
                .SOS => {
                    const len = try reader.takeInt(u16, .big);

                    const comp = try reader.takeByte();

                    if (comp != components) return error.JPEGUnsupportedComponentSize;

                    for (0..components) |_| {
                        var comp_id = try reader.takeByte();

                        if (component_zero_based) comp_id += 1;
                        if (comp_id > components) return error.JPEGInvalidComponentId;

                        if (component_specs[comp_id - 1].used) return error.JPEGComponentIdUsed;

                        component_specs[comp_id - 1].used = true;

                        const table_id = try reader.takeByte();
                        const dc_id = (table_id >> 4);
                        const ac_id = (table_id & 0x0F);

                        if (dc_id > 3 or ac_id > 3) return error.JPEGInvalidComponentTable;

                        component_specs[comp_id - 1].dc_id = dc_id;
                        component_specs[comp_id - 1].ac_id = ac_id;
                    }

                    start_of_selection = try reader.takeByte();
                    end_of_selection = try reader.takeByte();
                    const successive_approximation = try reader.takeByte();
                    successive_approximation_high = successive_approximation >> 4;
                    successive_approximation_low = successive_approximation & 0x0F;

                    if (start_of_selection != 0 or end_of_selection != 63) return error.JPEGInvalidStartOfSelection;
                    if (successive_approximation_high != 0 or successive_approximation_high != 0) return error.JPEGInvalidSuccessiveApproximation;

                    if ((len - 6 - (2 * components)) != 0) return error.JPEGFaulty;
                    break;
                },
                .NONE => {
                    std.debug.print("Somthing went wrong parsing marker 0xFF{X}\n", .{current_byte});
                    return error.JPEGFault;
                },
                .SOF2 => {
                    return error.JPEGProgressiveScanNotImplementedYet;
                },
                else => {
                    std.debug.print("Unknown marker 0xFF{X}\n", .{current_byte});
                    //break;
                    return error.JPEGMarkerNotImplementedYet;
                },
            }
        }
        current_byte_or_err = reader.takeByte();
    }

    current_byte_or_err = reader.takeByte();

    var huffman_data: std.ArrayList(u8) = .empty;
    defer huffman_data.deinit(allocator);

    while (current_byte_or_err != error.EndOfStream) {
        const current_byte = try current_byte_or_err;

        if (current_byte == @intFromEnum(JPEGMarker.START)) {
            const next = reader.takeByte();

            if (try next > 0x00 and try next < 0xC0) return error.JPEGInvalidHuffmanStream;

            switch (JPEGMarker.as(try next)) {
                .EOI => break,
                .NONE => {},
                .RST0, .RST1, .RST2, .RST3, .RST4, .RST5, .RST6, .RST7 => {
                    try dc_reset_markers.append(allocator, huffman_data.items.len - 1);
                    current_byte_or_err = reader.takeByte();
                    continue;
                },
                .START => {
                    current_byte_or_err = next;
                    continue;
                },
                else => unreachable,
            }
        }
        try huffman_data.append(allocator, current_byte);
        current_byte_or_err = reader.takeByte();
    }

    for (&dc_huffman_tables) |*table| {
        var code: usize = 0;
        for (0..16) |i| {
            for (table.offsets[i]..table.offsets[i + 1]) |j| {
                table.codes[j] = code;
                //std.debug.print("i: {d}, code: 0x{b}\n", .{ i, code });
                code += 1;
            }
            code <<= 1;
        }
    }

    for (&ac_huffman_tables) |*table| {
        var code: usize = 0;
        for (0..16) |i| {
            for (table.offsets[i]..table.offsets[i + 1]) |j| {
                table.codes[j] = code;
                code += 1;
            }
            code <<= 1;
        }
    }

    var blocks: std.ArrayList(Block) = try .initCapacity(allocator, block_width_real * block_height_real);
    defer blocks.deinit(allocator);
    blocks.appendNTimesAssumeCapacity(.{ .arr = .{.{0} ** 64} ** 3 }, block_width_real * block_height_real);

    var huff_reader = BitReader.init(&huffman_data.items);

    var previous_DC: [3]isize = .{0} ** 3;

    var y: usize = 0;
    var x: usize = 0;

    //std.debug.print("hf {d}, vf {d}", .{ sampling_factor_horizontal, sampling_factor_vertical });

    const dc_reset_interval_real = dc_reset_interval * sampling_factor_horizontal * sampling_factor_vertical;

    while (y < block_height) : (y += sampling_factor_vertical) {
        //std.debug.print("y, {d}\n", .{y});
        while (x < block_width) : (x += sampling_factor_horizontal) {
            //std.debug.print("x, {d}\n", .{x});
            const i = y * block_width_real + x;

            if (dc_reset_interval_real != 0 and
                i % dc_reset_interval_real == 0 or
                std.mem.containsAtLeast(usize, dc_reset_markers.items, 1, &[_]usize{huff_reader.byte}))
            {
                previous_DC[0] = 0;
                previous_DC[1] = 0;
                previous_DC[2] = 0;
                try huff_reader.byteAlign();
            }

            for (0..components) |j| {
                for (0..component_specs[j].sampling_factor_vertical) |v| {
                    horiz: for (0..component_specs[j].sampling_factor_horizontal) |h| {
                        const block_index = (y + v) * block_width_real + (x + h);
                        //std.debug.print("block index: {d}\n", .{block_index});
                        var sym_len: ?usize = null;
                        var current_code: usize = 0;

                        sym1: for (0..16) |k| {
                            const bit = try huff_reader.next();

                            current_code = (current_code << 1) | bit;
                            const current_table = dc_huffman_tables[component_specs[j].dc_id];
                            for (current_table.offsets[k]..current_table.offsets[k + 1]) |l| {
                                if (current_code == current_table.codes[l]) {
                                    sym_len = current_table.symbols[l];
                                    break :sym1;
                                }
                            }
                        }

                        if (sym_len == null) {
                            std.debug.print("\n", .{});
                            for (0..64) |a| {
                                std.debug.print("{d}, ", .{blocks.items[24].arr[j][a]});
                            }
                            std.debug.print("\ncomponennt: {d}, y: {d}, x: {d}, v: {d}, h: {d}, current code: 0x{b}, curr byte: 0b{b}\n", .{ j, y, x, v, h, current_code, huffman_data.items[huff_reader.byte] });
                            return error.JPEGFaultyReadHuffmanSymbol;
                        }

                        var coefficient: isize = @intCast(try huff_reader.nextN(sym_len.?));
                        const usize1: usize = 1;

                        if (sym_len.? != 0 and coefficient < (usize1 << @intCast(sym_len.? - 1))) coefficient -= @as(isize, @intCast((usize1 << @intCast(sym_len.?)) - 1));

                        const dc_coeff = coefficient + previous_DC[j];
                        //std.debug.print("{d}, {d}, {d}\n", .{ block_index, block_width_real, block_height_real });
                        blocks.items[block_index].arr[j][0] = dc_coeff;
                        previous_DC[j] = dc_coeff;

                        var ac: usize = 1;
                        while (ac < 64) {
                            sym_len = null;
                            current_code = 0;

                            sym2: for (0..16) |k| {
                                const bit = try huff_reader.next();
                                current_code = (current_code << 1) | bit;
                                const current_table = ac_huffman_tables[component_specs[j].ac_id];
                                for (current_table.offsets[k]..current_table.offsets[k + 1]) |l| {
                                    if (current_code == current_table.codes[l]) {
                                        sym_len = current_table.symbols[l];
                                        break :sym2;
                                    }
                                }
                            }
                            if (sym_len == null) return error.JPEGFaultyReadHuffmanSymbol;

                            if (sym_len.? == 0x00) continue :horiz;

                            var num_zeros = sym_len.? >> 4;
                            const coeff_length = sym_len.? & 0x0F;
                            coefficient = 0;

                            if (sym_len.? == 0xF0) num_zeros = 16;

                            if (ac + num_zeros >= 64) {
                                for (0..64) |k| {
                                    if (k % 8 == 0) std.debug.print("\n", .{});
                                    std.debug.print("{d}, ", .{blocks.items[block_index].arr[j][zigZagTable[k]]});
                                }
                                return error.JPEGZeroRunLenghtExceeded;
                            }
                            ac += num_zeros;

                            if (coeff_length > 10) return error.JPEGACCoefficientLenthTooLarge;

                            if (coeff_length != 0) {
                                coefficient = @intCast(try huff_reader.nextN(coeff_length));
                                if (coefficient < (usize1 << @intCast(coeff_length - 1))) coefficient -= @as(isize, @intCast((usize1 << @intCast(coeff_length)) - 1));
                                blocks.items[block_index].arr[j][zigZagTable[ac]] = coefficient;
                                ac += 1;
                            }
                        }
                    }
                }
            }
        }
        x = 0;
    }

    y = 0;
    x = 0;
    while (y < block_height) : (y += sampling_factor_vertical) {
        while (x < block_width) : (x += sampling_factor_horizontal) {
            for (0..components) |j| {
                const component = component_specs[j];
                for (0..component.sampling_factor_vertical) |v| {
                    for (0..component.sampling_factor_horizontal) |h| {
                        for (0..64) |k| {
                            blocks.items[(y + v) * block_width_real + (x + h)].arr[j][k] *= @intCast(quantization_tables[component_specs[j].quant_id][k]);
                        }
                    }
                }
            }
        }
        x = 0;
    }

    y = 0;
    x = 0;
    while (y < block_height) : (y += sampling_factor_vertical) {
        while (x < block_width) : (x += sampling_factor_horizontal) {
            for (0..components) |j| {
                const component = component_specs[j];
                for (0..component.sampling_factor_vertical) |v| {
                    for (0..component.sampling_factor_horizontal) |h| {
                        DiscreteCosineTransform.inverse(blocks.items[(y + v) * block_width_real + (x + h)].arr[j][0..]);
                    }
                }
            }
        }
        x = 0;
    }

    var image = Image{ .width = @intCast(width), .height = @intCast(height), .original_format = .JPEG };
    image.pixels = try .initCapacity(allocator, width * height);
    errdefer image.pixels.deinit(allocator);

    for (0..height) |h| {
        const block_y = @divFloor(h, 8);
        const pixel_y = @mod(h, 8);
        for (0..width) |w| {
            const block_x = @divFloor(w, 8);
            const pixel_x = @mod(w, 8);

            const light_block_index = block_y * block_width_real + block_x;
            const chroma_block_index = (@divFloor(block_y, sampling_factor_vertical) * sampling_factor_vertical) * block_width_real + (@divFloor(block_x, sampling_factor_horizontal) * sampling_factor_horizontal);

            const light_pixel_index = pixel_y * 8 + pixel_x;
            const chroma_pixel_index = @divFloor(@mod(h, 8 * sampling_factor_vertical), sampling_factor_vertical) * 8 + @divFloor(@mod(w, 8 * sampling_factor_horizontal), sampling_factor_horizontal);

            const yc = blocks.items[light_block_index].arr[0][light_pixel_index];
            const cb = blocks.items[chroma_block_index].arr[1][chroma_pixel_index];
            const cr = blocks.items[chroma_block_index].arr[2][chroma_pixel_index];

            const r: u8 = @intFromFloat(@max(0, @min(255, @as(f64, @floatFromInt(yc + 128)) + 1.402 * @as(f64, @floatFromInt(cr)))));
            const g: u8 = @intFromFloat(@max(0, @min(255, @as(f64, @floatFromInt(yc + 128)) - 0.34414 * @as(f64, @floatFromInt(cb)) - 0.71414 * @as(f64, @floatFromInt((cr))))));
            const b: u8 = @intFromFloat(@max(0, @min(255, @as(f64, @floatFromInt(yc + 128)) + 1.772 * @as(f64, @floatFromInt(cb)))));

            image.pixels.appendAssumeCapacity(.{
                .r = r,
                .g = g,
                .b = b,
            });
        }
    }
    return image;
}
