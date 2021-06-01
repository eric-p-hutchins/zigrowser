const std = @import("std");
const expect = std.testing.expect;
const c = @import("c.zig");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Document = @import("document.zig");

const fonts = @import("fonts.zig");
const Fonts = fonts.Fonts;

const layout = @import("layout.zig");
const Layout = layout.Layout;

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

    var flags = c.IMG_Init(c.IMG_INIT_PNG);
    if (flags != c.IMG_INIT_PNG) {
        const err: [*c]const u8 = c.IMG_GetError();
        std.log.info("{}", .{std.mem.span(err)});
    }

    var theFonts: Fonts = try Fonts.init(&fba.allocator);

    var screen: ZigrowserScreen = ZigrowserScreen.init();

    // var startPageHtml = try Document.init(&fba.allocator, std.mem.spanZ(startPage));
    var startPageHtml = try Document.init(&fba.allocator, std.mem.spanZ(testPage));
    defer startPageHtml.deinit(&fba.allocator);

    const mainLayout = try Layout.init(&fba.allocator, screen.renderer.?, &theFonts, &startPageHtml.body.element.node, 0, 0, 640, 480);

    var done: bool = false;
    while (!done) {
        var event: c.SDL_Event = std.mem.zeroes(c.SDL_Event);
        while (c.SDL_PollEvent(&event) != 0) {
            if (event.type == c.SDL_QUIT) {
                done = true;
            }
        }
        try screen.clear(255, 255, 255);
        try mainLayout.draw(&screen);
        try screen.present();
        _ = c.SDL_Delay(20);
    }
}
