const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const HTMLElement = @import("html.zig").Element;

const Fonts = @import("fonts.zig").Fonts;

const ZigrowserScreen = @import("screen.zig").ZigrowserScreen;

pub const Layout = struct {
    const This = @This();
    children: ArrayList(This),
    fonts: *Fonts,
    element: HTMLElement,
    x: i32,
    y: i32,
    w: i32,
    h: i32,

    pub fn init(allocator: *Allocator, fonts: *Fonts, element: HTMLElement, x: i32, y: i32, w: i32, h: i32) !Layout {
        return Layout{
            .children = ArrayList(This).init(allocator),
            .fonts = fonts,
            .element = element,
            .x = x,
            .y = y,
            .w = w,
            .h = h,
        };
    }

    pub fn draw(this: This, screen: ZigrowserScreen) !void {
        try screen.drawStringFT(this.fonts.fonts.items[0], this.element.innerText, this.x, this.y);
    }
};
