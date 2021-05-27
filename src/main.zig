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

const ZigrowserScreen = @import("screen.zig").ZigrowserScreen;

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

    var library: *FT_Library = try initFreeType();
    // var dejavuSansFace: *FT_Face = try loadFace(library, "DejaVuSans.ttf");
    var dejavuSansFace: *FT_Face = try loadFaceMemory(library, dejaVuEmbed, dejaVuEmbed.len);

    var errorCode = c.FT_Set_Char_Size(dejavuSansFace.*, 0, 16 * 64, 72, 72);
    if (errorCode != 0) {
        std.log.info("error setting char size. code: {}", .{errorCode});
    }

    var screen: ZigrowserScreen = ZigrowserScreen.init();

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
        try screen.clear(255, 255, 255);
        try screen.drawStringFT(dejavuSansFace, startPageHtml.body.text, 0, 0);
        try screen.present();
        _ = c.SDL_Delay(20);
    }
}
