const std = @import("std");

const c = @import("c.zig");

const bdf = @import("bdf.zig");
const BdfFont = bdf.BdfFont;
const BdfChar = bdf.BdfChar;
const BoundingBox = bdf.BoundingBox;

const FT_Face = c.FT_Face;
const FT_Bitmap = c.FT_Bitmap;

const Error = error{
    WindowOrRendererCreationError,
};

pub const Screen = struct {
    const This = @This();
    window: *c.SDL_Window,
    renderer: *c.SDL_Renderer,
    hiDpi: bool = false,

    pub fn init() !Screen {
        const width: c_int = 640;
        const height: c_int = 480;
        var window: ?*c.SDL_Window = null;
        var renderer: ?*c.SDL_Renderer = null;
        if (c.SDL_CreateWindowAndRenderer(width, height, c.SDL_WINDOW_ALLOW_HIGHDPI, &window, &renderer) != 0) {
            std.log.err("Error creating window or renderer: {any}", .{std.mem.span(c.SDL_GetError())});
            return error.WindowOrRendererCreationError;
        }

        c.SDL_ShowWindow(window);

        var hiDpi: bool = false;

        var w: c_int = 0;
        var h: c_int = 0;
        c.SDL_GL_GetDrawableSize(window, &w, &h);

        if (w == width * 2) {
            hiDpi = true;
        }

        return Screen{
            .window = window.?,
            .renderer = renderer.?,
            .hiDpi = hiDpi,
        };
    }

    pub fn clear(this: This, r: u8, g: u8, b: u8) !void {
        _ = c.SDL_SetRenderDrawColor(this.renderer, r, g, b, c.SDL_ALPHA_OPAQUE);
        _ = c.SDL_RenderClear(this.renderer);
    }

    pub fn present(this: This) !void {
        _ = c.SDL_RenderPresent(this.renderer);
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
                if (this.hiDpi) {
                    rect.*.x *= 2;
                    rect.*.y *= 2;
                }
                rect.*.w = if (this.hiDpi) 2 else 1;
                rect.*.h = if (this.hiDpi) 2 else 1;
                _ = c.SDL_RenderDrawRect(this.renderer, rect);
            }
            ptr = @intToPtr([*c]u8, @ptrToInt(ptr) + @intCast(usize, pitch));
        }
    }

    pub fn fillRect(this: This, x: i32, y: i32, w: u32, h: u32, r: u8, g: u8, b: u8) !void {
        var arenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arenaAllocator.deinit();

        _ = c.SDL_SetRenderDrawColor(this.renderer, r, g, b, c.SDL_ALPHA_OPAQUE);
        var rect: *c.SDL_Rect = try arenaAllocator.allocator.create(c.SDL_Rect);
        rect.*.x = @intCast(c_int, x);
        rect.*.y = @intCast(c_int, y);
        if (this.hiDpi) {
            rect.*.x *= 2;
            rect.*.y *= 2;
        }
        rect.*.w = if (this.hiDpi) @intCast(c_int, w * 2) else @intCast(c_int, w);
        rect.*.h = if (this.hiDpi) @intCast(c_int, h * 2) else @intCast(c_int, h);
        _ = c.SDL_RenderFillRect(this.renderer, rect);
    }

    pub fn drawString(this: This, font: *BdfFont, string: []const u8, x: i32, y: i32, r: u8, g: u8, b: u8) !void {
        var currentX: i32 = x;
        var originY: i32 = y + @intCast(i32, font.boundingBox.height);
        for (string) |byte, i| {
            const char: BdfChar = font.getChar(byte) catch try font.getChar(' ');
            const boundingBox: BoundingBox = char.boundingBox orelse font.boundingBox;
            const charX = @intCast(i32, currentX) + boundingBox.xOff;
            const charY = originY - @intCast(i32, boundingBox.height) - boundingBox.yOff;
            try this.drawChar(font, byte, charX, charY, r, g, b);
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

    pub fn drawChar(this: This, font: *BdfFont, codePoint: u8, x: i32, y: i32, r: u8, g: u8, b: u8) !void {
        var arenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arenaAllocator.deinit();

        _ = c.SDL_SetRenderDrawColor(this.renderer, r, g, b, c.SDL_ALPHA_OPAQUE);
        for (font.chars.items) |char, i| {
            if (char.codePoint == codePoint) {
                for (char.lines) |line, j| {
                    for (line) |byte, k| {
                        if (byte == '#') {
                            var rect: *c.SDL_Rect = try arenaAllocator.allocator.create(c.SDL_Rect);
                            rect.*.x = @intCast(c_int, k) + @intCast(c_int, x);
                            rect.*.y = @intCast(c_int, j) + @intCast(c_int, y);
                            if (this.hiDpi) {
                                rect.*.x *= 2;
                                rect.*.y *= 2;
                            }
                            rect.*.w = if (this.hiDpi) 2 else 1;
                            rect.*.h = if (this.hiDpi) 2 else 1;
                            _ = c.SDL_RenderDrawRect(this.renderer, rect);
                        }
                    }
                }
            }
        }
    }
};
