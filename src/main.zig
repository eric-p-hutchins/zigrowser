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

const welcomePage = @embedFile("welcomePage.html");

const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator(.{});
var gpa = GeneralPurposeAllocator{};

const Error = error{FreeTypeInitializationError};

const Screen = @import("screen.zig").Screen;

pub fn main() anyerror!void {
    std.log.info("Welcome to Zigrowser.", .{});

    if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
        std.log.err("Error initializing SDL: {any}", .{std.mem.span(c.SDL_GetError())});
        std.process.exit(1);
    }
    defer c.SDL_Quit();

    var flags = c.IMG_Init(c.IMG_INIT_PNG);
    if (flags != c.IMG_INIT_PNG) {
        const err: [*c]const u8 = c.IMG_GetError();
        std.log.info("Error initializing SDL_image: {any}", .{std.mem.span(err)});
    }
    defer c.IMG_Quit();

    var theFonts: Fonts = try Fonts.init(&gpa.allocator);
    defer theFonts.deinit();

    var screen: Screen = try Screen.init();

    var welcomePageDocument = try Document.init(&gpa.allocator, std.mem.spanZ(welcomePage));
    defer welcomePageDocument.deinit(&gpa.allocator);

    var bodyNode = &welcomePageDocument.body.element.node;

    const mainLayout = try Layout.init(&gpa.allocator, screen.renderer, &theFonts, bodyNode, 0, 0, 640, 480);

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
