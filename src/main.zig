const std = @import("std");
const expect = std.testing.expect;
const c = @import("c.zig");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const bdf = @import("bdf.zig");
const BDFFont = bdf.BDFFont;
const BDFChar = bdf.BDFChar;
const BoundingBox = bdf.BoundingBox;

const html = @import("html.zig");
const HTML = html.HTML;

const glean = @embedFile("glean-5-10.bdf");
const victor12 = @embedFile("VictorMono-Medium-12.bdf");
const dejaVuEmbed = @embedFile("DejaVuSans.ttf");
const startPage = @embedFile("startPage.html");

var buf: [10_000_000]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&buf);
const gpa = std.heap.GeneralPurposeAllocator(.{}){};

const FT_Library = c.FT_Library;
const FT_Face = c.FT_Face;
const FT_Bitmap = c.FT_Bitmap;

const Error = error{FreeTypeInitializationError};

const ZigrowserScreen = struct {
    const This = @This();
    window: ?*c.SDL_Window,
    renderer: ?*c.SDL_Renderer,
    hiDPI: bool = false,

    pub fn init(window: ?*c.SDL_Window, renderer: ?*c.SDL_Renderer) ZigrowserScreen {
        var hiDPITest: bool = false;

        var w: c_int = 0;
        var h: c_int = 0;
        c.SDL_GL_GetDrawableSize(window, &w, &h);

        if (w == 320 * 2) {
            hiDPITest = true;
        }

        return ZigrowserScreen{
            .window = window,
            .renderer = renderer,
            .hiDPI = hiDPITest,
        };
    }

    pub fn drawBitmap(this: This, bitmap: FT_Bitmap, x: i32, y: i32) !void {
        var arenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arenaAllocator.deinit();

        const rows = bitmap.rows;
        const width = bitmap.width;
        const pitch = bitmap.pitch;
        var ptr = bitmap.buffer;
        var i: c_int = 0;
        while (i < rows) : (i += 1) {
            var j: c_int = 0;
            while (j < width) : (j += 1) {
                var color = @intToPtr([*c]u8, @ptrToInt(ptr) + @intCast(usize, j)).*;
                _ = c.SDL_SetRenderDrawColor(this.renderer, 255 - color, 255 - color, 255 - color, c.SDL_ALPHA_OPAQUE);
                var rect: *c.SDL_Rect = try arenaAllocator.allocator.create(c.SDL_Rect);
                rect.*.x = @intCast(c_int, x) + @intCast(c_int, j);
                rect.*.y = @intCast(c_int, y) + @intCast(c_int, i);
                if (this.hiDPI) {
                    rect.*.x *= 2;
                    rect.*.y *= 2;
                }
                rect.*.w = if (this.hiDPI) 2 else 1;
                rect.*.h = if (this.hiDPI) 2 else 1;
                _ = c.SDL_RenderDrawRect(this.renderer, rect);
            }
            ptr = @intToPtr([*c]u8, @ptrToInt(ptr) + @intCast(usize, pitch));
        }
    }

    pub fn drawString(this: This, font: BDFFont, string: []const u8, x: i32, y: i32) !void {
        var currentX: i32 = x;
        var originY: i32 = y + @intCast(i32, font.boundingBox.height);
        for (string) |byte, i| {
            const char: BDFChar = try font.getChar(byte);
            const boundingBox: BoundingBox = char.boundingBox orelse font.boundingBox;
            const charX = @intCast(i32, currentX) + boundingBox.xOff;
            const charY = originY - @intCast(i32, boundingBox.height) - boundingBox.yOff;
            try this.drawChar(font, byte, charX, charY);
            currentX += @intCast(i32, char.dWidth);
        }
    }

    pub fn drawStringFT(this: This, face: *FT_Face, string: []const u8, x: i32, y: i32) !void {
        var currentX: i32 = x;
        for (string) |byte, i| {
            var charIndex = c.FT_Get_Char_Index(face.*, byte);
            var errorCode = c.FT_Load_Glyph(face.*, charIndex, 0);
            var glyph: *c.FT_GlyphSlotRec_ = @ptrCast(*c.FT_FaceRec, face.*).glyph;
            var charX: i32 = currentX + @intCast(i32, glyph.bitmap_left);
            var charY: i32 = 0 + 40 - glyph.bitmap_top;
            errorCode = c.FT_Render_Glyph(glyph, c.FT_Render_Mode_.FT_RENDER_MODE_NORMAL);
            try this.drawBitmap(glyph.bitmap, charX, charY);
            currentX += @intCast(i32, @divFloor(glyph.advance.x, 64));
        }
    }

    pub fn drawChar(this: This, font: BDFFont, codePoint: u8, x: i32, y: i32) !void {
        var arenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arenaAllocator.deinit();

        _ = c.SDL_SetRenderDrawColor(this.renderer, 0, 0, 0, c.SDL_ALPHA_OPAQUE);
        for (font.chars) |char, i| {
            if (char.codePoint == codePoint) {
                for (char.lines) |line, j| {
                    for (line) |byte, k| {
                        if (byte == '#') {
                            var rect: *c.SDL_Rect = try arenaAllocator.allocator.create(c.SDL_Rect);
                            rect.*.x = @intCast(c_int, k) + @intCast(c_int, x);
                            rect.*.y = @intCast(c_int, j) + @intCast(c_int, y);
                            if (this.hiDPI) {
                                rect.*.x *= 2;
                                rect.*.y *= 2;
                            }
                            rect.*.w = if (this.hiDPI) 2 else 1;
                            rect.*.h = if (this.hiDPI) 2 else 1;
                            _ = c.SDL_RenderDrawRect(this.renderer, rect);
                        }
                    }
                }
            }
        }
    }
};

pub fn initFreeType() !*FT_Library {
    var library: ?*FT_Library = try fba.allocator.create(FT_Library);
    _ = c.FT_Init_FreeType(library);
    return library orelse error.FreeTypeInitializationError;
}

pub fn loadFace(library: *FT_Library, path: [*c]const u8) !*FT_Face {
    var face: ?*FT_Face = try fba.allocator.create(FT_Face);
    _ = c.FT_New_Face(library.*, path, 0, face);
    return face orelse error.FreeTypeInitializationError;
}

pub fn loadFaceMemory(library: *FT_Library, memory: [*c]const u8, length: c_long) !*FT_Face {
    var face: ?*FT_Face = try fba.allocator.create(FT_Face);
    _ = c.FT_New_Memory_Face(library.*, memory, length, 0, face);
    return face orelse error.FreeTypeInitializationError;
}

pub fn main() anyerror!void {
    std.log.info("Welcome to Zigrowser.", .{});

    if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
        std.log.err("Error initializing", .{});
        std.process.exit(1);
    }
    defer c.SDL_Quit();
    var window: ?*c.SDL_Window = null;
    var renderer: ?*c.SDL_Renderer = null;
    if (c.SDL_CreateWindowAndRenderer(320, 240, c.SDL_WINDOW_ALLOW_HIGHDPI, &window, &renderer) != 0) {
        std.log.err("Error creating window", .{});
        c.SDL_Quit();
        std.process.exit(1);
    }

    c.SDL_ShowWindow(window);

    var library: *FT_Library = try initFreeType();
    // var dejavuSansFace: *FT_Face = try loadFace(library, "DejaVuSans.ttf");
    var dejavuSansFace: *FT_Face = try loadFaceMemory(library, dejaVuEmbed, dejaVuEmbed.len);

    var errorCode = c.FT_Set_Char_Size(dejavuSansFace.*, 0, 16 * 64, 72, 72);
    if (errorCode != 0) {
        std.log.info("error setting char size. code: {}", .{errorCode});
    }

    var screen: ZigrowserScreen = ZigrowserScreen.init(window, renderer);

    var gleanFont: BDFFont = try BDFFont.parse(&fba.allocator, std.mem.spanZ(glean));
    var victor12Font: BDFFont = try BDFFont.parse(&fba.allocator, std.mem.spanZ(victor12));

    const startPageHtml = try HTML.parse(&fba.allocator, std.mem.spanZ(startPage));

    var done: bool = false;
    while (!done) {
        var event: c.SDL_Event = std.mem.zeroes(c.SDL_Event);
        while (c.SDL_PollEvent(&event) != 0) {
            if (event.type == c.SDL_QUIT) {
                done = true;
            }
        }
        _ = c.SDL_SetRenderDrawColor(renderer, 255, 255, 255, c.SDL_ALPHA_OPAQUE);
        _ = c.SDL_RenderClear(renderer);
        try screen.drawStringFT(dejavuSansFace, startPageHtml.body.text, 0, 0);
        _ = c.SDL_RenderPresent(renderer);
        _ = c.SDL_Delay(20);
    }
}
