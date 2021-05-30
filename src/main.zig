const std = @import("std");
const expect = std.testing.expect;
const c = @import("c.zig");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const bdf = @import("bdf.zig");
const BDFFont = bdf.BDFFont;
const BDFChar = bdf.BDFChar;
const BoundingBox = bdf.BoundingBox;

const Document = @import("document.zig");

const fonts = @import("fonts.zig");
const Fonts = fonts.Fonts;

const layout = @import("layout.zig");
const Layout = layout.Layout;

const glean = @embedFile("glean-5-10.bdf");
const victor12 = @embedFile("VictorMono-Medium-12.bdf");
const startPage = @embedFile("startPage.html");
const testPage = @embedFile("testPage.html");

var buf: [10_000_000]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&buf);

const Error = error{FreeTypeInitializationError};

const ZigrowserScreen = @import("screen.zig").ZigrowserScreen;

pub fn main() anyerror!void {
    std.log.info("Welcome to Zigrowser.", .{});

    if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
        std.log.err("Error initializing", .{});
        std.process.exit(1);
    }
    defer c.SDL_Quit();

    var theFonts: Fonts = try Fonts.init(&fba.allocator);

    var screen: ZigrowserScreen = ZigrowserScreen.init();

    var gleanFont: BDFFont = try BDFFont.parse(&fba.allocator, std.mem.spanZ(glean));
    var victor12Font: BDFFont = try BDFFont.parse(&fba.allocator, std.mem.spanZ(victor12));

    var startPageHtml = try Document.init(&fba.allocator, std.mem.spanZ(startPage));
    // const startPageHtml = try Document.parse(&fba.allocator, std.mem.spanZ(testPage));

    defer startPageHtml.deinit(&fba.allocator);

    const mainLayout = try Layout.init(&fba.allocator, &theFonts, startPageHtml.body, 0, 0, 640, 480);

    var done: bool = false;
    while (!done) {
        var event: c.SDL_Event = std.mem.zeroes(c.SDL_Event);
        while (c.SDL_PollEvent(&event) != 0) {
            if (event.type == c.SDL_QUIT) {
                done = true;
            }
        }
        try screen.clear(255, 255, 255);
        try mainLayout.draw(screen);
        try screen.present();
        _ = c.SDL_Delay(20);
    }
}
