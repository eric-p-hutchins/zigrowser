const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const TextContainer = @import("html.zig").TextContainer;

const Fonts = @import("fonts.zig").Fonts;

const ZigrowserScreen = @import("screen.zig").ZigrowserScreen;

pub const Layout = struct {
    const This = @This();
    children: ArrayList(This),
    fonts: *Fonts,
    html: TextContainer,
    x: i32,
    y: i32,
    w: i32,
    h: i32,

    pub fn init(allocator: *Allocator, fonts: *Fonts, html: TextContainer, x: i32, y: i32, w: i32, h: i32) !Layout {
        return Layout{
            .children = ArrayList(This).init(allocator),
            .fonts = fonts,
            .html = html,
            .x = x,
            .y = y,
            .w = w,
            .h = h,
        };
    }

    pub fn draw(this: This, screen: ZigrowserScreen) !void {
        try screen.drawStringFT(this.fonts.fonts.items[0], this.html.text, this.x, this.y);
    }
};
