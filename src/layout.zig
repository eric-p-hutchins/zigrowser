const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;
const Document = @import("document.zig");
const HtmlElement = @import("html.zig").HtmlElement;
const Node = @import("node.zig");
const Element = @import("element.zig");

const Fonts = @import("fonts.zig").Fonts;

const CompositeCssRuleSet = @import("css.zig").CompositeCssRuleSet;
const CssDeclaration = @import("css.zig").Declaration;
const CssColor = @import("css.zig").CssColor;
const CssRgbColor = @import("css.zig").CssRgbColor;
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
    srcW: ?u32, // the src width of an image
    srcH: ?u32, // the src height of an image
    backgroundColor: ?CssRgbColor = null,
    textColor: CssRgbColor = CssRGBColor{ .r = 0, .g = 0, .b = 0 },
    marginTop: i32 = 0,
    marginBottom: i32 = 0,
    marginLeft: i32 = 0,
    marginRight: i32 = 0,
    paddingTop: i32 = 0,
    paddingBottom: i32 = 0,
    paddingLeft: i32 = 0,
    paddingRight: i32 = 0,
    texture: ?*c.SDL_Texture = null,

    pub fn init(allocator: *Allocator, renderer: *c.SDL_Renderer, fonts: *Fonts, node: *Node, x: i32, y: i32, w: u32, h: u32) !Layout {
        var childrenPtr = try allocator.create(AutoHashMap(*Node, *This));
        childrenPtr.* = AutoHashMap(*Node, *This).init(allocator);

        var marginTop: i32 = 0;
        var marginBottom: i32 = 0;
        var marginLeft: i32 = 0;
        var marginRight: i32 = 0;
        var paddingTop: i32 = 0;
        var paddingBottom: i32 = 0;
        var paddingLeft: i32 = 0;
        var paddingRight: i32 = 0;

        var backgroundColor: ?CssRgbColor = null;
        var textColor: CssRgbColor = CssRgbColor{ .r = 0, .g = 0, .b = 0 };

        var newW: ?u32 = null;
        var newH: ?u32 = null;
        var srcW: ?u32 = null;
        var srcH: ?u32 = null;
        var styleW: ?u32 = null;
        var styleH: ?u32 = null;
        var texture: ?*c.SDL_Texture = null;
        if (std.mem.eql(u8, "IMG", node.nodeName)) {
            var element = @fieldParentPtr(Element, "node", node);
            var srcPath = element.getAttribute("src");
            if (srcPath.len > 0) {
                const new_path: []const u8 = try std.mem.concat(allocator, u8, &[_][]const u8{ "src/", srcPath });
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
                    srcW = newW;
                    srcH = newH;
                    c.SDL_FreeSurface(image);
                }
            }
        }

        var compositeCssRuleSet: *CompositeCssRuleSet = try CompositeCssRuleSet.init(allocator);
        var ruleSet = &compositeCssRuleSet.ruleSet;
        defer compositeCssRuleSet.ruleSet.deinit();

        const document: ?*Document = node.ownerDocument;
        if (document != null) {
            var documentRuleSet: *CssRuleSet = document.?.cssRuleSet;
            try compositeCssRuleSet.addRuleSet(documentRuleSet);
        }

        if (node.nodeType == 1) {
            var element = @fieldParentPtr(Element, "node", node);
            var htmlElement = @fieldParentPtr(HtmlElement, "element", element);
            try compositeCssRuleSet.addRuleSet(htmlElement.style);
        }

        var declarations: ArrayList(CssDeclaration) = try ruleSet.getDeclarations(node, allocator);
        for (declarations.items) |declaration| {
            if (std.mem.eql(u8, "width", declaration.property)) {
                switch (declaration.value) {
                    CssValueType.length => |length| {
                        switch (length.unit) {
                            CssLengthUnit.px => {
                                switch (length.value) {
                                    CssNumber.int => |int_length| {
                                        styleW = @intCast(u32, int_length);
                                        if (std.mem.eql(u8, "IMG", node.nodeName) and styleH == null) {
                                            newH = @floatToInt(u32, @intToFloat(f64, styleW.?) / @intToFloat(f64, newW.?) * @intToFloat(f64, newH.?));
                                        }
                                        newW = styleW;
                                    },
                                    CssNumber.float => |float_length| {},
                                }
                            },
                            CssLengthUnit.percent => {
                                var float_val: f64 = undefined;
                                switch (length.value) {
                                    CssNumber.int => |int_length| {
                                        float_val = @intToFloat(f64, int_length);
                                    },
                                    CssNumber.float => |float_length| {
                                        float_val = float_length;
                                    },
                                }
                                newW = @floatToInt(u32, @round(float_val / 100.0 * @intToFloat(f64, w)));
                            },
                        }
                    },
                    else => {},
                }
            } else if (std.mem.eql(u8, "margin-top", declaration.property)) {
                switch (declaration.value) {
                    CssValueType.length => |length| {
                        switch (length.unit) {
                            CssLengthUnit.px => switch (length.value) {
                                CssNumber.int => |int_length| {
                                    marginTop = @intCast(i32, int_length);
                                },
                                CssNumber.float => |float_length| {},
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
                            CssLengthUnit.px => switch (length.value) {
                                CssNumber.int => |int_length| {
                                    marginLeft = @intCast(i32, int_length);
                                },
                                CssNumber.float => |float_length| {},
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
                            CssLengthUnit.px => switch (length.value) {
                                CssNumber.int => |int_length| {
                                    marginBottom = @intCast(i32, int_length);
                                },
                                CssNumber.float => |float_length| {},
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
                            CssLengthUnit.px => switch (length.value) {
                                CssNumber.int => |int_length| {
                                    marginRight = @intCast(i32, int_length);
                                },
                                CssNumber.float => |float_length| {},
                            },
                            else => {},
                        }
                    },
                    else => {},
                }
            } else if (std.mem.eql(u8, "margin", declaration.property)) {
                switch (declaration.value) {
                    CssValueType.length => |length| {
                        switch (length.unit) {
                            CssLengthUnit.px => switch (length.value) {
                                CssNumber.int => |int_length| {
                                    var val = @intCast(i32, int_length);
                                    marginTop = val;
                                    marginBottom = val;
                                    marginLeft = val;
                                    marginRight = val;
                                },
                                CssNumber.float => |float_length| {},
                            },
                            else => {},
                        }
                    },
                    else => {},
                }
            } else if (std.mem.eql(u8, "padding-top", declaration.property)) {
                switch (declaration.value) {
                    CssValueType.length => |length| {
                        switch (length.unit) {
                            CssLengthUnit.px => switch (length.value) {
                                CssNumber.int => |int_length| {
                                    paddingTop = @intCast(i32, int_length);
                                },
                                CssNumber.float => |float_length| {},
                            },
                            else => {},
                        }
                    },
                    else => {},
                }
            } else if (std.mem.eql(u8, "padding-left", declaration.property)) {
                switch (declaration.value) {
                    CssValueType.length => |length| {
                        switch (length.unit) {
                            CssLengthUnit.px => switch (length.value) {
                                CssNumber.int => |int_length| {
                                    paddingLeft = @intCast(i32, int_length);
                                },
                                CssNumber.float => |float_length| {},
                            },
                            else => {},
                        }
                    },
                    else => {},
                }
            } else if (std.mem.eql(u8, "padding-bottom", declaration.property)) {
                switch (declaration.value) {
                    CssValueType.length => |length| {
                        switch (length.unit) {
                            CssLengthUnit.px => switch (length.value) {
                                CssNumber.int => |int_length| {
                                    paddingBottom = @intCast(i32, int_length);
                                },
                                CssNumber.float => |float_length| {},
                            },
                            else => {},
                        }
                    },
                    else => {},
                }
            } else if (std.mem.eql(u8, "padding-right", declaration.property)) {
                switch (declaration.value) {
                    CssValueType.length => |length| {
                        switch (length.unit) {
                            CssLengthUnit.px => switch (length.value) {
                                CssNumber.int => |int_length| {
                                    paddingRight = @intCast(i32, int_length);
                                },
                                CssNumber.float => |float_length| {},
                            },
                            else => {},
                        }
                    },
                    else => {},
                }
            } else if (std.mem.eql(u8, "padding", declaration.property)) {
                switch (declaration.value) {
                    CssValueType.length => |length| {
                        switch (length.unit) {
                            CssLengthUnit.px => switch (length.value) {
                                CssNumber.int => |int_length| {
                                    var val = @intCast(i32, int_length);
                                    paddingTop = val;
                                    paddingBottom = val;
                                    paddingLeft = val;
                                    paddingRight = val;
                                },
                                CssNumber.float => |float_length| {},
                            },
                            else => {},
                        }
                    },
                    else => {},
                }
            } else if (std.mem.eql(u8, "background-color", declaration.property)) {
                switch (declaration.value) {
                    CssValueType.color => |color| {
                        backgroundColor = color.toRgbColor();
                    },
                    else => {},
                }
            } else if (std.mem.eql(u8, "color", declaration.property)) {
                switch (declaration.value) {
                    CssValueType.color => |color| {
                        textColor = color.toRgbColor();
                    },
                    else => {},
                }
            }
        }
        declarations.deinit();

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
            .srcW = srcW,
            .srcH = srcH,
            .w = newW orelse w,
            .h = newH orelse h,
            .marginTop = marginTop,
            .marginBottom = marginBottom,
            .marginLeft = marginLeft,
            .marginRight = marginRight,
            .paddingTop = paddingTop,
            .paddingBottom = paddingBottom,
            .paddingLeft = paddingLeft,
            .paddingRight = paddingRight,
            .texture = texture,
            .backgroundColor = backgroundColor,
            .textColor = textColor,
        };
    }

    pub fn draw(this: This, screen: *Screen) anyerror!void {
        if (this.backgroundColor) |backgroundColor| {
            var x = this.x;
            var y = this.y;
            var w = this.w;
            var h = this.h;
            var r = this.backgroundColor.?.r;
            var g = this.backgroundColor.?.g;
            var b = this.backgroundColor.?.b;
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
                var r = this.textColor.r;
                var g = this.textColor.g;
                var b = this.textColor.b;
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

        var x = this.x + this.marginLeft + this.paddingLeft;
        var y = this.y + this.marginTop + this.paddingTop;
        var w = this.w - @intCast(u32, this.paddingLeft) - @intCast(u32, this.paddingRight) - @intCast(u32, this.marginLeft) - @intCast(u32, this.marginRight);
        var h = this.h - @intCast(u32, this.paddingTop) - @intCast(u32, this.paddingBottom) - @intCast(u32, this.marginTop) - @intCast(u32, this.marginBottom);
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
