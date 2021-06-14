const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;
const Document = @import("document.zig");
const HTMLElement = @import("html.zig").HTMLElement;
const Node = @import("node.zig");
const Element = @import("element.zig");

const Fonts = @import("fonts.zig").Fonts;

const CssDeclaration = @import("css.zig").Declaration;
const CssColor = @import("css.zig").CssColor;
const CssRGBColor = @import("css.zig").CssRGBColor;
const CssRuleSet = @import("css.zig").RuleSet;
const CssNumber = @import("css.zig").CssNumber;
const CssValueType = @import("css.zig").CssValueType;
const CssValue = @import("css.zig").CssValue;
const CssLengthType = @import("css.zig").CssLengthType;
const CssLengthUnit = @import("css.zig").CssLengthUnit;

const Screen = @import("screen.zig").Screen;

const c = @import("c.zig");

pub const Layout = struct {
    const This = @This();
    allocator: *Allocator,
    renderer: *c.SDL_Renderer,
    children: *AutoHashMap(*Node, *This),
    fonts: *Fonts,
    node: *Node,
    x: i32,
    y: i32,
    w: u32,
    h: u32,
    backgroundColor: ?CssColor = null,
    textColor: CssColor = CssColor{ .rgb = CssRGBColor{ .r = 0, .g = 0, .b = 0 } },
    marginTop: i32 = 0,
    marginBottom: i32 = 0,
    marginLeft: i32 = 0,
    marginRight: i32 = 0,
    texture: ?*c.SDL_Texture = null,

    pub fn init(allocator: *Allocator, renderer: *c.SDL_Renderer, fonts: *Fonts, node: *Node, x: i32, y: i32, w: u32, h: u32) !Layout {
        var childrenPtr = try allocator.create(AutoHashMap(*Node, *This));
        childrenPtr.* = AutoHashMap(*Node, *This).init(allocator);

        var marginTop: i32 = 0;
        var marginBottom: i32 = 0;
        var marginLeft: i32 = 0;
        var marginRight: i32 = 0;

        var backgroundColor: ?CssColor = null;
        var textColor: CssColor = CssColor{ .rgb = CssRGBColor{ .r = 0, .g = 0, .b = 0 } };

        const document: ?*Document = node.ownerDocument;
        if (document != null) {
            var ruleSet: *CssRuleSet = document.?.cssRuleSet;
            var declarations: ArrayList(CssDeclaration) = try ruleSet.getDeclarations(node, allocator);
            for (declarations.items) |declaration| {
                if (std.mem.eql(u8, "margin-top", declaration.property)) {
                    switch (declaration.value) {
                        CssValueType.length => |length| {
                            switch (length.unit) {
                                CssLengthUnit.px => {
                                    switch (length.value) {
                                        CssNumber.int => |int_length| {
                                            marginTop = @intCast(i32, int_length);
                                        },
                                        CssNumber.float => |float_length| {},
                                    }
                                },
                                else => {},
                            }
                        },
                        else => {},
                    }
                } else if (std.mem.eql(u8, "margin-left", declaration.property)) {
                    switch (declaration.value) {
                        CssValueType.length => |length| {
                            switch (length.unit) {
                                CssLengthUnit.px => {
                                    switch (length.value) {
                                        CssNumber.int => |int_length| {
                                            marginLeft = @intCast(i32, int_length);
                                        },
                                        CssNumber.float => |float_length| {},
                                    }
                                },
                                else => {},
                            }
                        },
                        else => {},
                    }
                } else if (std.mem.eql(u8, "margin-bottom", declaration.property)) {
                    switch (declaration.value) {
                        CssValueType.length => |length| {
                            switch (length.unit) {
                                CssLengthUnit.px => {
                                    switch (length.value) {
                                        CssNumber.int => |int_length| {
                                            marginBottom = @intCast(i32, int_length);
                                        },
                                        CssNumber.float => |float_length| {},
                                    }
                                },
                                else => {},
                            }
                        },
                        else => {},
                    }
                } else if (std.mem.eql(u8, "margin-right", declaration.property)) {
                    switch (declaration.value) {
                        CssValueType.length => |length| {
                            switch (length.unit) {
                                CssLengthUnit.px => {
                                    switch (length.value) {
                                        CssNumber.int => |int_length| {
                                            marginRight = @intCast(i32, int_length);
                                        },
                                        CssNumber.float => |float_length| {},
                                    }
                                },
                                else => {},
                            }
                        },
                        else => {},
                    }
                } else if (std.mem.eql(u8, "background-color", declaration.property)) {
                    switch (declaration.value) {
                        CssValueType.color => |color| {
                            backgroundColor = color;
                        },
                        else => {},
                    }
                } else if (std.mem.eql(u8, "color", declaration.property)) {
                    switch (declaration.value) {
                        CssValueType.color => |color| {
                            textColor = color;
                        },
                        else => {},
                    }
                }
            }
            declarations.deinit();
        }

        var newW: ?u32 = null;
        var newH: ?u32 = null;
        var texture: ?*c.SDL_Texture = null;
        if (std.mem.eql(u8, "IMG", node.nodeName)) {
            var element: *Element = @fieldParentPtr(Element, "node", node);
            // TODO: Get the actual image properties that have already been parsed to determine 'src'
            if (std.mem.indexOf(u8, element.outerHTML, "src=\"")) |startIndex| {
                if (std.mem.indexOf(u8, element.outerHTML[startIndex + "src=\"".len ..], "\"")) |endIndex| {
                    const path: []const u8 = element.outerHTML[startIndex + "src=\"".len .. startIndex + "src=\"".len + endIndex];
                    const new_path: []const u8 = try std.mem.concat(allocator, u8, &[_][]const u8{ "src/", path });
                    const new_path_null_term: [:0]const u8 = try allocator.dupeZ(u8, new_path);
                    var new_path_c: [*c]const u8 = @ptrCast([*c]const u8, new_path_null_term);
                    const image: ?*c.SDL_Surface = c.IMG_Load(new_path_c);
                    if (image == null) {
                        const err: [*c]const u8 = c.IMG_GetError();
                        std.log.info("{any}", .{std.mem.span(err)});
                    } else {
                        texture = c.SDL_CreateTextureFromSurface(renderer, image);
                        if (texture == null) {
                            c.SDL_LogError(c.SDL_LOG_CATEGORY_APPLICATION, "Couldn't create texture from surface: %s", c.SDL_GetError());
                        }
                        newW = @intCast(u32, image.?.w);
                        newH = @intCast(u32, image.?.h);
                        c.SDL_FreeSurface(image);
                    }
                }
            }
        }

        if (std.mem.eql(u8, "#text", node.nodeName)) {
            var firstNonSpace: ?usize = null;
            var lastNonSpace: ?usize = null;
            for (node.textContent.?) |byte, i| {
                if (byte != ' ' and byte != '\n') {
                    if (firstNonSpace == null) {
                        firstNonSpace = i;
                    }
                    lastNonSpace = i;
                }
            }
            var total: usize = 0;
            if (firstNonSpace != null) {
                if (firstNonSpace.? > 0) {
                    total = 1;
                }
                var extent = node.textContent.?[firstNonSpace.? .. lastNonSpace.? + 1];
                for (extent) |byte, i| {
                    if (extent[i] == ' ' or extent[i] == '\n') {
                        if (extent[i - 1] != ' ' and extent[i - 1] != '\n') {
                            total += 1;
                        }
                    } else {
                        total += 1;
                    }
                }
            }
            newW = 16 * @intCast(u32, total);
        }

        return Layout{
            .allocator = allocator,
            .renderer = renderer,
            .children = childrenPtr,
            .fonts = fonts,
            .node = node,
            .x = x,
            .y = y,
            .w = newW orelse w,
            .h = newH orelse h,
            .marginTop = marginTop,
            .marginBottom = marginBottom,
            .marginLeft = marginLeft,
            .marginRight = marginRight,
            .texture = texture,
            .backgroundColor = backgroundColor,
            .textColor = textColor,
        };
    }

    pub fn draw(this: This, screen: *Screen) anyerror!void {
        if (this.backgroundColor) |backgroundColor| {
            var x = if (screen.hiDpi) this.x * 2 else this.x;
            var y = if (screen.hiDpi) this.y * 2 else this.y;
            var w = if (screen.hiDpi) this.w * 2 else this.w;
            var h = if (screen.hiDpi) this.h * 2 else this.h;
            var r = this.backgroundColor.?.rgb.r;
            var g = this.backgroundColor.?.rgb.g;
            var b = this.backgroundColor.?.rgb.b;
            try screen.fillRect(x, y, w, h, r, g, b);
        }
        if (this.node.textContent != null) {
            var firstNonSpace: ?usize = null;
            var lastNonSpace: ?usize = null;
            for (this.node.textContent.?) |byte, i| {
                if (byte != ' ' and byte != '\n') {
                    if (firstNonSpace == null) {
                        firstNonSpace = i;
                    }
                    lastNonSpace = i;
                }
            }
            var total: usize = 0;
            if (firstNonSpace != null) {
                if (firstNonSpace.? > 0) {
                    total = 1;
                }
                var extent = this.node.textContent.?[firstNonSpace.? .. lastNonSpace.? + 1];
                var r = this.textColor.rgb.r;
                var g = this.textColor.rgb.g;
                var b = this.textColor.rgb.b;
                try screen.drawString(this.fonts.bdfFonts.items[2], extent, this.x, this.y, r, g, b);
            }
        }

        if (std.mem.eql(u8, "IMG", this.node.nodeName) and this.texture != null) {
            var rect: *c.SDL_Rect = try this.allocator.create(c.SDL_Rect);
            rect.*.x = @intCast(c_int, this.x);
            rect.*.y = @intCast(c_int, this.y);
            if (screen.hiDpi) {
                rect.*.x *= 2;
                rect.*.y *= 2;
            }
            rect.*.w = if (screen.hiDpi) @intCast(c_int, this.w * 2) else @intCast(c_int, this.w);
            rect.*.h = if (screen.hiDpi) @intCast(c_int, this.h * 2) else @intCast(c_int, this.h);
            _ = c.SDL_RenderCopy(this.renderer, this.texture, null, rect);
            this.allocator.destroy(rect);
        }

        var x = this.x + this.marginLeft;
        var y = this.y + this.marginTop;
        var w = this.w - @intCast(u32, this.marginLeft) - @intCast(u32, this.marginRight);
        var h = this.h - @intCast(u32, this.marginTop) - @intCast(u32, this.marginBottom);
        var lineHeight: usize = 16;
        for (this.node.childNodes.items) |node| {
            if (this.children.get(node) == null) {
                var nodeLayout: *This = try this.allocator.create(This);
                nodeLayout.* = try This.init(this.allocator, this.renderer, this.fonts, node, x, y, w, h);
                x += @intCast(i32, nodeLayout.w);
                if (std.mem.eql(u8, "BR", node.nodeName)) {
                    x = this.x + this.marginLeft;
                    y += @intCast(i32, lineHeight);
                    lineHeight = 16;
                }
                if (std.mem.eql(u8, "IMG", node.nodeName)) {
                    lineHeight = nodeLayout.h;
                }
                try this.children.put(node, nodeLayout);
            }
            try this.children.get(node).?.draw(screen);
        }
    }
};
