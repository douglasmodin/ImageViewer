const std = @import("std");

const csdl = @cImport({
    @cDefine("SDL_MAIN_HANDLED", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_main.h");
    @cInclude("SDL3_image/SDL_image.h");
    @cInclude("SDL3_ttf/SDL_ttf.h");
});
pub const InitFlags = csdl.SDL_InitFlags;
pub const INIT_VIDEO = csdl.SDL_INIT_VIDEO;

pub const WINDOW_FULLSCREEN = csdl.SDL_WINDOW_FULLSCREEN;
pub const WINDOW_RESIZABLE = csdl.SDL_WINDOW_RESIZABLE;
pub const WINDOW_BORDERLESS = csdl.SDL_WINDOW_BORDERLESS;
pub const WINDOW_TRANSPARENT = csdl.SDL_WINDOW_TRANSPARENT;

pub const HitTest = csdl.SDL_HitTest;

pub const HitTestResult = csdl.SDL_HitTestResult;

pub const HITTEST_NORMAL = csdl.SDL_HITTEST_NORMAL;
pub const HITTEST_DRAGGABLE = csdl.SDL_HITTEST_DRAGGABLE;
pub const HITTEST_RESIZE_TOPLEFT = csdl.SDL_HITTEST_RESIZE_TOPLEFT;
pub const HITTEST_RESIZE_TOP = csdl.SDL_HITTEST_RESIZE_TOP;
pub const HITTEST_RESIZE_TOPRIGHT = csdl.SDL_HITTEST_RESIZE_TOPRIGHT;
pub const HITTEST_RESIZE_RIGHT = csdl.SDL_HITTEST_RESIZE_RIGHT;
pub const HITTEST_RESIZE_BOTTOMRIGHT = csdl.SDL_HITTEST_RESIZE_BOTTOMRIGHT;
pub const HITTEST_RESIZE_BOTTOM = csdl.SDL_HITTEST_RESIZE_BOTTOM;
pub const HITTEST_RESIZE_BOTTOMLEFT = csdl.SDL_HITTEST_RESIZE_BOTTOMLEFT;
pub const HITTEST_RESIZE_LEFT = csdl.SDL_HITTEST_RESIZE_LEFT;

pub const HINT_MAIN_CALLBACK_RATE = csdl.SDL_HINT_MAIN_CALLBACK_RATE;
pub const HINT_RENDER_DRIVER = csdl.SDL_HINT_RENDER_DRIVER;
pub const PIXELFORMAT_RGBX8888 = csdl.SDL_PIXELFORMAT_RGBX8888;
pub const PIXELFORMAT_RGBA8888 = csdl.SDL_PIXELFORMAT_RGBA8888;
pub const PIXELFORMAT_RGBA32 = csdl.SDL_PIXELFORMAT_RGBA32;
pub const PIXELFORMAT_RGBX32 = csdl.SDL_PIXELFORMAT_RGBX32;

pub const TEXTUREACCESS_STATIC = csdl.SDL_TEXTUREACCESS_STATIC;
pub const TEXTUREACCESS_STREAMING = csdl.SDL_TEXTUREACCESS_STREAMING;
pub const TEXTUREACCESS_TARGET = csdl.SDL_TEXTUREACCESS_TARGET;

pub const APP_CONTINUE = csdl.SDL_APP_CONTINUE;
pub const APP_SUCCESS = csdl.SDL_APP_SUCCESS;
pub const APP_FAILURE = csdl.SDL_APP_FAILURE;

pub const EventFilter = csdl.SDL_EventFilter;

pub const EVENT_QUIT = csdl.SDL_EVENT_QUIT;
pub const EVENT_WINDOW_RESIZED = csdl.SDL_EVENT_WINDOW_RESIZED;
pub const EVENT_WINDOW_EXPOSED = csdl.SDL_EVENT_WINDOW_EXPOSED;
pub const EVENT_WINDOW_PIXEL_SIZE_CHANGED = csdl.SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED;
pub const EVENT_WINDOW_CLOSE_REQUESTED = csdl.SDL_EVENT_WINDOW_CLOSE_REQUESTED;
pub const EVENT_KEY_DOWN = csdl.SDL_EVENT_KEY_DOWN;
pub const EVENT_KEY_UP = csdl.SDL_EVENT_KEY_UP;
pub const EVENT_MOUSE_MOTION = csdl.SDL_EVENT_MOUSE_MOTION;
pub const EVENT_MOUSE_BUTTON_DOWN = csdl.SDL_EVENT_MOUSE_BUTTON_DOWN;
pub const EVENT_MOUSE_BUTTON_UP = csdl.SDL_EVENT_MOUSE_BUTTON_UP;
pub const EVENT_MOUSE_WHEEL = csdl.SDL_EVENT_MOUSE_WHEEL;

pub const SDLK_F = csdl.SDLK_F;
pub const SDLK_R = csdl.SDLK_R;
pub const SDLK_Q = csdl.SDLK_Q;
pub const SDLK_F11 = csdl.SDLK_F11;

pub const MOUSE_BUTTON_LEFT = csdl.SDL_BUTTON_LEFT;

pub const PixelFormat = csdl.SDL_PixelFormat;
pub const TextureAccess = csdl.SDL_TextureAccess;
pub const BlendMode = csdl.SDL_BlendMode;

pub const BLENDMODE_BLEND = csdl.SDL_BLENDMODE_BLEND;

pub const ScaleMode = csdl.SDL_ScaleMode;
pub const SCALEMODE_NEAREST = csdl.SDL_SCALEMODE_NEAREST;
pub const SCALEMODE_LINEAR = csdl.SDL_SCALEMODE_LINEAR;
pub const SCALEMODE_PIXELART = csdl.SDL_SCALEMODE_PIXELART;

pub const Rect = csdl.SDL_Rect;
pub const FRect = csdl.SDL_FRect;

pub const Point = csdl.SDL_Point;
pub const FPoint = csdl.SDL_FPoint;

pub const FlipMode = csdl.SDL_FlipMode;
pub const FLIP_NONE = csdl.SDL_FLIP_NONE;
pub const FLIP_HORIZONTAL = csdl.SDL_FLIP_HORIZONTAL;
pub const FLIP_VERTICAL = csdl.SDL_FLIP_VERTICAL;

pub const Window = csdl.SDL_Window;
pub const WindowFlags = csdl.SDL_WindowFlags;

pub const Renderer = csdl.SDL_Renderer;
pub const Surface = csdl.SDL_Surface;

pub const Texture = csdl.SDL_Texture;
pub const Vertex = csdl.SDL_Vertex;

pub const Font = csdl.TTF_Font;
pub const TextEngine = csdl.TTF_TextEngine;
pub const Text = csdl.TTF_Text;

pub const AppResult = csdl.SDL_AppResult;
pub const Event = csdl.SDL_Event;

// Convinience not in SDL

pub fn start(argv: []const [:0]const u8, on_init: fn ([*c]?*anyopaque, c_int, [*c][*c]u8) callconv(.c) AppResult, on_iterate: fn (?*anyopaque) callconv(.c) AppResult, on_event: fn (?*anyopaque, [*c]Event) callconv(.c) AppResult, on_quit: fn (?*anyopaque, AppResult) callconv(.c) void) c_int {
    return @intCast(csdl.SDL_EnterAppMainCallbacks(@intCast(argv.len), @ptrCast(@constCast(argv)), on_init, on_iterate, on_event, on_quit));
}

// Adapted from Raylib
pub fn renderFillCircle(renderer: ?*Renderer, center_x: f32, center_y: f32, radius: f32) void {
    if (radius <= 0.0) return; // Avoid div by zero

    const step_length: f32 = 10.0;
    var angle: f32 = 0;

    var vertices: [36 * 3]Vertex = undefined;

    var r_u8: u8 = 0;
    var g_u8: u8 = 0;
    var b_u8: u8 = 0;
    var a_u8: u8 = 0;

    _ = getRenderDrawColor(renderer, &r_u8, &g_u8, &b_u8, &a_u8);

    const r: f32 = @as(f32, @floatFromInt(r_u8)) / 255.0;
    const g: f32 = @as(f32, @floatFromInt(g_u8)) / 255.0;
    const b: f32 = @as(f32, @floatFromInt(b_u8)) / 255.0;
    const a: f32 = @as(f32, @floatFromInt(a_u8)) / 255.0;

    for (0..36) |i| {
        vertices[i * 3 + 0].position = .{ .x = center_x, .y = center_y };
        vertices[i * 3 + 0].color = .{ .r = r, .g = g, .b = b, .a = a };

        vertices[i * 3 + 1].position = .{ .x = (center_x + @cos(std.math.rad_per_deg * (angle + step_length)) * radius), .y = (center_y + @sin(std.math.rad_per_deg * (angle + step_length)) * radius) };
        vertices[i * 3 + 1].color = .{ .r = r, .g = g, .b = b, .a = a };

        vertices[i * 3 + 2].position = .{ .x = (center_x + @cos(std.math.rad_per_deg * angle) * radius), .y = (center_y + @sin(std.math.rad_per_deg * angle) * radius) };
        vertices[i * 3 + 2].color = .{ .r = r, .g = g, .b = b, .a = a };

        angle += step_length;
    }

    _ = csdl.SDL_RenderGeometry(renderer, null, &vertices, vertices.len, null, 0);
}

// SDL Functions

pub fn enterAppMainCallbacks(argc: c_int, argv: [*c][*c]u8, on_init: fn ([*c]?*anyopaque, c_int, [*c][*c]u8) callconv(.c) AppResult, on_iterate: fn (?*anyopaque) callconv(.c) AppResult, on_event: fn (?*anyopaque, [*c]Event) callconv(.c) AppResult, on_quit: fn (?*anyopaque, AppResult) callconv(.c) void) c_int {
    return @intCast(csdl.SDL_EnterAppMainCallbacks(argc, argv, on_init, on_iterate, on_event, on_quit));
}

pub fn runApp(argv: []const [:0]const u8, func: fn (c_int, [*c][*c]u8) callconv(.c) c_int) c_int {
    return csdl.SDL_RunApp(@intCast(argv.len), @ptrCast(@constCast(argv)), func, null);
}

pub fn init(flags: InitFlags) bool {
    return csdl.SDL_Init(flags);
}

pub fn addEventWatch(filter: EventFilter, userdata: ?*anyopaque) bool {
    return csdl.SDL_AddEventWatch(filter, userdata);
}

pub fn pollEvent(event: *Event) bool {
    return csdl.SDL_PollEvent(event);
}

pub fn createWindow(title: [:0]const u8, w: i32, h: i32, flags: u64) ?*Window {
    return csdl.SDL_CreateWindow(title, @as(c_int, w), @as(c_int, h), @as(c_ulonglong, flags));
}

pub fn destroyWindow(window: ?*Window) void {
    return csdl.SDL_DestroyWindow(window);
}

pub fn setWindowIcon(window: ?*Window, icon: ?*Surface) bool {
    return csdl.SDL_SetWindowIcon(window, icon);
}

pub fn setAppMetadata(appname: [:0]const u8, appversion: [:0]const u8, appidentifier: [:0]const u8) bool {
    return csdl.SDL_SetAppMetadata(appname, appversion, appidentifier);
}

pub fn setWindowSize(window: ?*Window, w: c_int, h: c_int) bool {
    return csdl.SDL_SetWindowSize(window, w, h);
}

pub fn getWindowFlags(window: ?*Window) WindowFlags {
    return csdl.SDL_GetWindowFlags(window);
}

pub fn setWindowFullscreen(window: ?*Window, fullscreen: bool) bool {
    return csdl.SDL_SetWindowFullscreen(window, fullscreen);
}
pub fn getWindowPosition(window: ?*Window, x: *isize, y: *isize) bool {
    var c_x: c_int = 0;
    var c_y: c_int = 0;
    const ret = csdl.SDL_GetWindowPosition(window, &c_x, &c_y);

    x.* = @intCast(c_x);
    y.* = @intCast(c_y);
    return ret;
}

pub fn setWindowPosition(window: ?*Window, x: isize, y: isize) bool {
    return csdl.SDL_SetWindowPosition(window, @intCast(x), @intCast(y));
}

pub fn setWindowHitTest(window: ?*Window, callback: HitTest, callback_data: ?*anyopaque) bool {
    return csdl.SDL_SetWindowHitTest(window, callback, callback_data);
}

pub fn createRenderer(window: ?*Window, name: [:0]const u8) ?*Renderer {
    return csdl.SDL_CreateRenderer(window, name);
}

pub fn destroyRenderer(renderer: ?*Renderer) void {
    return csdl.SDL_DestroyRenderer(renderer);
}

pub fn renderClear(renderer: ?*Renderer) bool {
    return csdl.SDL_RenderClear(renderer);
}

pub fn renderPresent(renderer: ?*Renderer) bool {
    return csdl.SDL_RenderPresent(renderer);
}

pub fn renderTexture(renderer: ?*Renderer, texture: [*c]Texture, srcrect: [*c]const FRect, dstrect: [*c]const FRect) bool {
    return csdl.SDL_RenderTexture(renderer, texture, srcrect, dstrect);
}

pub fn renderTextureRotated(renderer: ?*Renderer, texture: [*c]Texture, srcrect: [*c]const FRect, dstrect: [*c]const FRect, angle: f64, center: ?*FPoint, flip: FlipMode) bool {
    return csdl.SDL_RenderTextureRotated(renderer, texture, srcrect, dstrect, angle, center, flip);
}

pub fn getRenderDrawColor(renderer: ?*Renderer, r: *u8, g: *u8, b: *u8, a: *u8) bool {
    return csdl.SDL_GetRenderDrawColor(renderer, r, g, b, a);
}

pub fn setRenderDrawColor(renderer: ?*Renderer, r: u8, g: u8, b: u8, a: u8) bool {
    return csdl.SDL_SetRenderDrawColor(renderer, r, g, b, a);
}

pub fn setRenderDrawBlendMode(renderer: ?*Renderer, blendMode: BlendMode) bool {
    return csdl.SDL_SetRenderDrawBlendMode(renderer, blendMode);
}

pub fn renderRect(renderer: ?*Renderer, rect: [*c]const FRect) bool {
    return csdl.SDL_RenderRect(renderer, rect);
}

pub fn renderFillRect(renderer: ?*Renderer, rect: [*c]const FRect) bool {
    return csdl.SDL_RenderFillRect(renderer, rect);
}

pub fn setRenderVSync(renderer: ?*Renderer, vsync: c_int) bool {
    return csdl.SDL_SetRenderVSync(renderer, vsync);
}

pub fn setHint(name: [*c]const u8, value: [*c]const u8) bool {
    return csdl.SDL_SetHint(name, value);
}

pub fn createSurface(width: usize, height: usize, format: PixelFormat) [*c]Surface {
    return @alignCast(csdl.SDL_CreateSurface(@intCast(width), @intCast(height), format));
}

pub fn createSurfaceFrom(width: usize, height: usize, format: PixelFormat, pixels: *anyopaque, pitch: usize) [*c]Surface {
    return csdl.SDL_CreateSurfaceFrom(@intCast(width), @intCast(height), format, pixels, @intCast(pitch));
}

pub fn createTexture(renderer: ?*Renderer, format: PixelFormat, access: TextureAccess, w: c_int, h: c_int) [*c]Texture {
    return csdl.SDL_CreateTexture(renderer, format, access, w, h);
}

pub fn destroyTexture(texture: [*c]Texture) void {
    return csdl.SDL_DestroyTexture(texture);
}

pub fn updateTexture(texture: [*c]Texture, rect: [*c]const Rect, pixels: ?*const anyopaque, pitch: c_int) bool {
    return csdl.SDL_UpdateTexture(texture, rect, pixels, pitch);
}

pub fn setTextureAlphaMod(texture: [*c]Texture, alpha: u8) bool {
    return csdl.SDL_SetTextureAlphaMod(texture, alpha);
}

pub fn setTextureScaleMode(texture: [*c]Texture, scaleMode: ScaleMode) bool {
    return csdl.SDL_SetTextureScaleMode(texture, scaleMode);
}

pub fn quit() void {
    csdl.SDL_Quit();
}

pub fn getTicksNS() u64 {
    return csdl.SDL_GetTicksNS();
}

// IMG

pub fn load(path: [*c]const u8) [*c]Surface {
    return csdl.IMG_Load(path);
}

pub fn loadTexture(renderer: ?*Renderer, path: [*c]const u8) [*c]Texture {
    return csdl.IMG_LoadTexture(renderer, path);
}

// TTF

pub fn textInit() bool {
    return csdl.TTF_Init();
}

pub fn textQuit() void {
    csdl.TTF_Quit();
}

pub fn openFont(file: [*c]const u8, ptsize: f32) ?*Font {
    return csdl.TTF_OpenFont(file, ptsize);
}

pub fn closeFont(font: ?*Font) void {
    csdl.TTF_CloseFont(font);
}

pub fn setFontSize(font: ?*Font, ptsize: f32) bool {
    return csdl.TTF_SetFontSize(font, ptsize);
}

pub fn createRendererTextEngine(renderer: ?*Renderer) ?*TextEngine {
    return csdl.TTF_CreateRendererTextEngine(renderer);
}

pub fn destroyRendererTextEngine(engine: TextEngine) void {
    csdl.TTF_DestroyRendererTextEngine(engine);
}

pub fn drawRendererText(text: ?*Text, x: f32, y: f32) bool {
    return csdl.TTF_DrawRendererText(text, x, y);
}

pub fn createText(engine: ?*TextEngine, font: ?*Font, text: [*c]const u8, length: usize) [*c]Text {
    return csdl.TTF_CreateText(engine, font, text, length);
}

pub fn destroyText(text: ?*Text) void {
    csdl.TTF_DestroyText(text);
}

pub fn getTextSize(text: ?*Text, w: *isize, h: *isize) bool {
    return csdl.TTF_GetTextSize(text, @ptrCast(w), @ptrCast(h));
}

pub fn setTextColor(text: ?*Text, r: u8, g: u8, b: u8, a: u8) bool {
    return csdl.TTF_SetTextColor(text, r, g, b, a);
}
