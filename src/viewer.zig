const std = @import("std");
const Image = @import("image.zig");
const sdl = @import("sdl/sdl.zig");

var error1 = @embedFile("resources/Error1.png");
var error2 = @embedFile("resources/Error2.png");
var error3 = @embedFile("resources/Error3.png");

var background_image_data = @embedFile("resources/checker.png");
var background_image: Image = undefined;
var background_texture: ?*sdl.Texture = null;

var image: Image = undefined;
var image_texture: ?*sdl.Texture = null;
var image_rect: sdl.FRect = .{ .x = 0.0, .y = 0.0, .w = 0.0, .h = 0.0 };
var image_angle: f64 = 0;

var window: ?*sdl.Window = null;
var window_width: f32 = 0;
var window_height: f32 = 0;
var window_x: f32 = 0;
var window_y: f32 = 0;

var renderer: ?*sdl.Renderer = null;

var running: bool = false;

var mouse_x: f32 = 0;
var mouse_y: f32 = 0;
var mouse_left_button_down = false;

fn initApp(io: std.Io, allocator: std.mem.Allocator, file_path: []const u8) !void {
    const start = std.Io.Clock.real.now(io);

    var err = false;
    image = Image.load(io, allocator, file_path) catch |e| blk: {
        err = true;
        switch (e) {
            Image.ImageError.NotImplementedYet => break :blk try Image.loadFromMemory(allocator, error3),
            Image.ImageError.UnsupportedFormat => break :blk try Image.loadFromMemory(allocator, error2),
            else => break :blk try Image.loadFromMemory(allocator, error1),
        }
    };
    defer image.pixels.deinit(allocator);

    background_image = try Image.loadFromMemory(allocator, background_image_data);
    defer background_image.pixels.deinit(allocator);

    const end = std.Io.Clock.real.now(io);
    std.debug.print("Total Loading time: {d}\n", .{@as(f64, @floatFromInt(end.nanoseconds - start.nanoseconds)) / std.time.ns_per_s});

    const format = blk: {
        if (err) break :blk "ERROR";
        switch (image.original_format) {
            .UNKNOWN => {
                break :blk "Unknown";
            },
            .BMP => {
                break :blk "BMP - Bitmap";
            },
            .QOI => {
                break :blk "QOI - Quite OK Image (Format)";
            },
            .PNG => {
                break :blk "PNG - Portable Network Graphic";
            },
            .WEBP => {
                break :blk "WEBP - WEB Picture";
            },
            .PPMP3 => {
                break :blk "PPM P3 - Portable Pixel Map (Human Readable)";
            },
            .PPMP6 => {
                break :blk "PPM P6 - Portable Pixel Map (Binary)";
            },
            .JPEG => {
                break :blk "JPEG - Joint Photographic Expert Group";
            },
        }
    };

    _ = sdl.init(sdl.INIT_VIDEO);

    const window_title = try std.fmt.allocPrintSentinel(allocator, "Modin's Image Viewer (v0.1) - {s} - {d}x{d}", .{ format, image.width, image.height }, 0);
    defer allocator.free(window_title);

    window_width = @floatFromInt(@min(@max(image.width, 800), 1920));
    window_height = @floatFromInt(@min(@max(image.height, 600), 1000));

    image_rect.w = @floatFromInt(image.width);
    image_rect.h = @floatFromInt(image.height);

    image_rect.x = (window_width - image_rect.w) / 2;
    image_rect.y = (window_height - image_rect.h) / 2;

    window = sdl.createWindow(window_title, @intFromFloat(window_width), @intFromFloat(window_height), sdl.WINDOW_RESIZABLE | sdl.WINDOW_TRANSPARENT);

    renderer = sdl.createRenderer(window, "");
    _ = sdl.setRenderVSync(renderer, 1);

    image_texture = sdl.createTexture(renderer, sdl.PIXELFORMAT_RGBA32, sdl.TEXTUREACCESS_STATIC, @intCast(image.width), @intCast(image.height));
    _ = sdl.setTextureScaleMode(image_texture, sdl.SCALEMODE_PIXELART);

    background_texture = sdl.createTexture(renderer, sdl.PIXELFORMAT_RGBA32, sdl.TEXTUREACCESS_STATIC, 64, 64);

    _ = sdl.updateTexture(background_texture, 0, background_image.pixels.items.ptr, 64 * 4);

    _ = sdl.updateTexture(image_texture, 0, image.pixels.items.ptr, @intCast(image.width * 4));
}

fn onEvent(_: ?*anyopaque, event: [*c]sdl.Event) callconv(.c) bool {
    if (event.*.type == sdl.EVENT_QUIT or event.*.type == sdl.EVENT_WINDOW_CLOSE_REQUESTED) running = false;
    if (event.*.type == sdl.EVENT_KEY_DOWN and event.*.key.key == sdl.SDLK_Q) {
        running = false;
    } else if (event.*.type == sdl.EVENT_WINDOW_EXPOSED) {
        render();
    } else if (event.*.type == sdl.EVENT_WINDOW_RESIZED) {
        window_width = @floatFromInt(event.*.window.data1);
        window_height = @floatFromInt(event.*.window.data2);

        image_rect.x = (window_width - image_rect.w) / 2;
        image_rect.y = (window_height - image_rect.h) / 2;
    } else if (event.*.type == sdl.EVENT_MOUSE_WHEEL) {
        const zoom_factor_x = if (image_rect.w >= 10 or event.*.wheel.y > 0) event.*.wheel.y * @as(f32, @floatFromInt(image.width)) / @as(f32, @floatFromInt(@max(image.width, image.height))) * 50 else 0;
        const zoom_factor_y = if (image_rect.h >= 10 or event.*.wheel.y > 0) event.*.wheel.y * @as(f32, @floatFromInt(image.height)) / @as(f32, @floatFromInt(@max(image.width, image.height))) * 50 else 0;
        image_rect.w += zoom_factor_x;
        image_rect.h += zoom_factor_y;

        image_rect.x += (((image_rect.x - mouse_x) / image_rect.w) * zoom_factor_x) - 0.3;
        image_rect.y += (((image_rect.y - mouse_y) / image_rect.h) * zoom_factor_y) - 0.3;
    } else if (event.*.type == sdl.EVENT_MOUSE_BUTTON_DOWN) {
        if (event.*.button.button == sdl.MOUSE_BUTTON_LEFT) {
            mouse_left_button_down = true;
        }
    } else if (event.*.type == sdl.EVENT_MOUSE_BUTTON_UP) {
        if (event.*.button.button == sdl.MOUSE_BUTTON_LEFT) {
            mouse_left_button_down = false;
        }
    } else if (event.*.type == sdl.EVENT_MOUSE_MOTION) {
        if (mouse_left_button_down) {
            image_rect.x += event.*.motion.xrel;
            image_rect.y += event.*.motion.yrel;
        }
        mouse_x = event.*.motion.x;
        mouse_y = event.*.motion.y;
    } else if (event.*.type == sdl.EVENT_KEY_DOWN and event.*.key.key == sdl.SDLK_R) {
        image_angle += 90;
        image_angle = @mod(image_angle, 360);
    }
    return false;
}

fn render() void {
    _ = sdl.renderClear(renderer);

    var x: usize = 0;
    var y: usize = 0;

    while (true) {
        _ = sdl.renderTexture(renderer, background_texture, null, &sdl.FRect{ .x = @floatFromInt(x), .y = @floatFromInt(y), .w = @floatFromInt(background_image.width), .h = @floatFromInt(background_image.height) });

        x += background_image.width;
        if (@as(f32, @floatFromInt(x)) >= window_width) {
            x = 0;
            y += background_image.height;
            if (@as(f32, @floatFromInt(y)) >= window_height) {
                break;
            }
        }
    }

    _ = sdl.renderTextureRotated(renderer, image_texture, null, &image_rect, image_angle, null, sdl.FLIP_NONE);
    _ = sdl.renderRect(renderer, &image_rect);

    _ = sdl.renderPresent(renderer);
}

fn quit() void {
    sdl.destroyTexture(image_texture);
    sdl.destroyRenderer(renderer);
    sdl.destroyWindow(window);

    sdl.quit();
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());

    if (args.len < 2) {
        try std.Io.File.stdout().writeStreamingAll(init.io, "Input file not provided.\nUsage: Viewer [file].{bmp,jpg,png,ppm,qoi}\n");
        return;
    }

    const file_path = args[1];
    try initApp(init.io, init.gpa, file_path);

    running = true;

    _ = sdl.addEventWatch(onEvent, null);
    var event: sdl.Event = undefined;

    while (running) {
        _ = sdl.pollEvent(&event);
        render();
    }

    quit();
}
