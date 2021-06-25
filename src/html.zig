const std = @import("std");
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

const Node = @import("node.zig");
const Attr = @import("attr.zig");
const EventTarget = @import("eventtarget.zig");
const Element = @import("element.zig");
const css = @import("css.zig");
const CssRuleSet = css.RuleSet;
const CssCascade = css.CssCascade;
const CssParser = css.CssParser;
const CssStyleDeclaration = css.CssStyleDeclaration;
const GenericCssRuleSet = css.GenericCssRuleSet;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const Text = struct {
    node: Node,
};

pub const HtmlElement = struct {
    const This = @This();

    allocator: *Allocator,
    element: Element,
    innerText: []u8,
    declaredStyle: *CssStyleDeclaration,
    cascade: ?*CssCascade,
    specifiedStyle: ?*CssStyleDeclaration,
    computedStyle: ?*CssStyleDeclaration,
    usedStyle: ?*CssStyleDeclaration,

    pub fn deinit(this: *This) void {
        this.allocator.free(this.innerText);
        this.allocator.free(this.element.node.nodeName);
        this.allocator.free(this.element.outerHTML);
        this.allocator.free(this.element.innerHTML);
        for (this.element.attributes.items) |attr| {
            this.allocator.free(attr.name);
            this.allocator.free(attr.value);
        }
        this.element.attributes.deinit();
        for (this.element.node.childNodes.items) |item| {
            if (item.nodeType == 1) {
                var element: *Element = @fieldParentPtr(Element, "node", item);
                var htmlElement: *HtmlElement = @fieldParentPtr(HtmlElement, "element", element);
                htmlElement.deinit();
            } else if (item.nodeType == 3) {
                this.allocator.free(item.nodeName);
                this.allocator.free(item.textContent.?);
                var textObj: *Text = @fieldParentPtr(Text, "node", item);
                textObj.node.childNodes.deinit();
                this.allocator.destroy(textObj);
            }
        }
        this.element.node.childNodes.deinit();
        if (this.usedStyle != null) {
            this.usedStyle.?.deinit();
            this.allocator.destroy(this.usedStyle.?);
        }
        if (this.computedStyle != null) {
            this.computedStyle.?.deinit();
            this.allocator.destroy(this.computedStyle.?);
        }
        if (this.computedStyle != null) {
            this.specifiedStyle.?.deinit();
            this.allocator.destroy(this.specifiedStyle.?);
        }
        if (this.computedStyle != null) {
            this.cascade.?.deinit();
            this.allocator.destroy(this.cascade.?);
        }
        this.declaredStyle.deinit();
        this.allocator.destroy(this.declaredStyle);
        this.allocator.destroy(this);
    }

    pub fn parseText(allocator: *Allocator, file: []const u8) !?Text {
        if (file[0] == '<') {
            return null;
        }
        var textContent: ArrayList(u8) = ArrayList(u8).init(allocator);
        defer textContent.deinit();

        var i: u32 = 0;
        while (file[i] != '<') : (i += 1) {
            try textContent.append(file[i]);
        }
        return Text{
            .node = Node{
                .eventTarget = try EventTarget.init(allocator),
                .isConnected = true,
                .nodeName = try allocator.dupe(u8, "#text"),
                .nodeType = 3,
                .textContent = try allocator.dupe(u8, textContent.items),
                .childNodes = ArrayList(*Node).init(allocator),
            },
        };
    }

    pub fn getCascade(self: *HtmlElement) !*CssCascade {
        if (self.cascade != null) return self.cascade.?;

        const declaredStyle = self.declaredStyle;

        self.cascade = try self.allocator.create(CssCascade);
        const cascade = self.cascade.?;
        cascade.* = CssCascade.init(self.allocator, self);

        cascade.cascade();

        // TODO: Eventually, do a real CSS cascade instead of hacking in the declared properties
        std.debug.print("TODO: Do a real cascade to bring in the properties from the style block...\n", .{});
        try cascade.setProperty("width", declaredStyle.getPropertyValue("width"), declaredStyle.getPropertyPriority("width"));
        try cascade.setProperty("height", declaredStyle.getPropertyValue("height"), declaredStyle.getPropertyPriority("height"));
        try cascade.setProperty("margin-top", declaredStyle.getPropertyValue("margin-top"), declaredStyle.getPropertyPriority("margin-top"));
        try cascade.setProperty("margin-bottom", declaredStyle.getPropertyValue("margin-bottom"), declaredStyle.getPropertyPriority("margin-bottom"));
        try cascade.setProperty("margin-left", declaredStyle.getPropertyValue("margin-left"), declaredStyle.getPropertyPriority("margin-left"));
        try cascade.setProperty("margin-right", declaredStyle.getPropertyValue("margin-right"), declaredStyle.getPropertyPriority("margin-right"));
        try cascade.setProperty("padding-top", declaredStyle.getPropertyValue("padding-top"), declaredStyle.getPropertyPriority("padding-top"));
        try cascade.setProperty("padding-bottom", declaredStyle.getPropertyValue("padding-bottom"), declaredStyle.getPropertyPriority("padding-bottom"));
        try cascade.setProperty("padding-left", declaredStyle.getPropertyValue("padding-left"), declaredStyle.getPropertyPriority("padding-left"));
        try cascade.setProperty("padding-right", declaredStyle.getPropertyValue("padding-right"), declaredStyle.getPropertyPriority("padding-right"));
        try cascade.setProperty("color", declaredStyle.getPropertyValue("color"), declaredStyle.getPropertyPriority("color"));
        try cascade.setProperty("background-color", declaredStyle.getPropertyValue("background-color"), declaredStyle.getPropertyPriority("background-color"));

        return cascade;
    }

    pub fn getSpecifiedStyle(self: *HtmlElement) !*CssStyleDeclaration {
        if (self.specifiedStyle != null) return self.specifiedStyle.?;

        const cascade = try self.getCascade();

        self.specifiedStyle = try self.allocator.create(CssStyleDeclaration);
        self.specifiedStyle.?.* = CssStyleDeclaration.init(self.allocator);

        var cascaded_width = cascade.getPropertyValue("width");
        var cascaded_height = cascade.getPropertyValue("height");
        var cascaded_margin_top = cascade.getPropertyValue("margin-top");
        var cascaded_margin_bottom = cascade.getPropertyValue("margin-bottom");
        var cascaded_margin_left = cascade.getPropertyValue("margin-left");
        var cascaded_margin_right = cascade.getPropertyValue("margin-right");
        var cascaded_padding_top = cascade.getPropertyValue("padding-top");
        var cascaded_padding_bottom = cascade.getPropertyValue("padding-bottom");
        var cascaded_padding_left = cascade.getPropertyValue("padding-left");
        var cascaded_padding_right = cascade.getPropertyValue("padding-right");
        var cascaded_color = cascade.getPropertyValue("color");
        var cascaded_background_color = cascade.getPropertyValue("background-color");
        if (cascaded_width.len == 0) {
            try self.specifiedStyle.?.setProperty("width", "auto", .Unimportant);
        } else {
            try self.specifiedStyle.?.setProperty("width", cascaded_width, cascade.getPropertyPriority("width"));
        }
        if (cascaded_height.len == 0) {
            try self.specifiedStyle.?.setProperty("height", "auto", .Unimportant);
        } else {
            try self.specifiedStyle.?.setProperty("height", cascaded_height, cascade.getPropertyPriority("height"));
        }
        if (cascaded_margin_top.len == 0) {
            try self.specifiedStyle.?.setProperty("margin-top", "0px", .Unimportant);
        } else {
            try self.specifiedStyle.?.setProperty("margin-top", cascaded_margin_top, cascade.getPropertyPriority("margin-top"));
        }
        if (cascaded_margin_bottom.len == 0) {
            try self.specifiedStyle.?.setProperty("margin-bottom", "0px", .Unimportant);
        } else {
            try self.specifiedStyle.?.setProperty("margin-bottom", cascaded_margin_bottom, cascade.getPropertyPriority("margin-bottom"));
        }
        if (cascaded_margin_left.len == 0) {
            try self.specifiedStyle.?.setProperty("margin-left", "0px", .Unimportant);
        } else {
            try self.specifiedStyle.?.setProperty("margin-left", cascaded_margin_left, cascade.getPropertyPriority("margin-left"));
        }
        if (cascaded_margin_right.len == 0) {
            try self.specifiedStyle.?.setProperty("margin-right", "0px", .Unimportant);
        } else {
            try self.specifiedStyle.?.setProperty("margin-right", cascaded_margin_right, cascade.getPropertyPriority("margin-right"));
        }
        if (cascaded_padding_top.len == 0) {
            try self.specifiedStyle.?.setProperty("padding-top", "0px", .Unimportant);
        } else {
            try self.specifiedStyle.?.setProperty("padding-top", cascaded_padding_top, cascade.getPropertyPriority("padding-top"));
        }
        if (cascaded_padding_bottom.len == 0) {
            try self.specifiedStyle.?.setProperty("padding-bottom", "0px", .Unimportant);
        } else {
            try self.specifiedStyle.?.setProperty("padding-bottom", cascaded_padding_bottom, cascade.getPropertyPriority("padding-bottom"));
        }
        if (cascaded_padding_left.len == 0) {
            try self.specifiedStyle.?.setProperty("padding-left", "0px", .Unimportant);
        } else {
            try self.specifiedStyle.?.setProperty("padding-left", cascaded_padding_left, cascade.getPropertyPriority("padding-left"));
        }
        if (cascaded_padding_right.len == 0) {
            try self.specifiedStyle.?.setProperty("padding-right", "0px", .Unimportant);
        } else {
            try self.specifiedStyle.?.setProperty("padding-right", cascaded_padding_right, cascade.getPropertyPriority("padding-right"));
        }
        if (cascaded_color.len == 0) {
            try self.specifiedStyle.?.setProperty("color", "rgb(0, 0, 0)", .Unimportant);
        } else {
            try self.specifiedStyle.?.setProperty("color", cascaded_color, cascade.getPropertyPriority("color"));
        }
        if (cascaded_background_color.len == 0) {
            try self.specifiedStyle.?.setProperty("background-color", "rgba(0, 0, 0, 0)", .Unimportant);
        } else {
            try self.specifiedStyle.?.setProperty("background-color", cascaded_background_color, cascade.getPropertyPriority("background-color"));
        }

        return self.specifiedStyle.?;
    }

    pub fn getComputedStyle(self: *HtmlElement) anyerror!*CssStyleDeclaration {
        if (self.computedStyle != null) return self.computedStyle.?;

        const specifiedStyle = try self.getSpecifiedStyle();

        self.computedStyle = try self.allocator.create(CssStyleDeclaration);
        self.computedStyle.?.* = CssStyleDeclaration.init(self.allocator);

        try self.computedStyle.?.setProperty("width", specifiedStyle.getPropertyValue("width"), specifiedStyle.getPropertyPriority("width"));
        try self.computedStyle.?.setProperty("height", specifiedStyle.getPropertyValue("height"), specifiedStyle.getPropertyPriority("height"));
        try self.computedStyle.?.setProperty("margin-top", specifiedStyle.getPropertyValue("margin-top"), specifiedStyle.getPropertyPriority("margin-top"));
        try self.computedStyle.?.setProperty("margin-bottom", specifiedStyle.getPropertyValue("margin-bottom"), specifiedStyle.getPropertyPriority("margin-bottom"));
        try self.computedStyle.?.setProperty("margin-left", specifiedStyle.getPropertyValue("margin-left"), specifiedStyle.getPropertyPriority("margin-left"));
        try self.computedStyle.?.setProperty("margin-right", specifiedStyle.getPropertyValue("margin-right"), specifiedStyle.getPropertyPriority("margin-right"));
        try self.computedStyle.?.setProperty("padding-top", specifiedStyle.getPropertyValue("padding-top"), specifiedStyle.getPropertyPriority("padding-top"));
        try self.computedStyle.?.setProperty("padding-bottom", specifiedStyle.getPropertyValue("padding-bottom"), specifiedStyle.getPropertyPriority("padding-bottom"));
        try self.computedStyle.?.setProperty("padding-left", specifiedStyle.getPropertyValue("padding-left"), specifiedStyle.getPropertyPriority("padding-left"));
        try self.computedStyle.?.setProperty("padding-right", specifiedStyle.getPropertyValue("padding-right"), specifiedStyle.getPropertyPriority("padding-right"));

        const parentNode: ?*Node = self.element.node.parentNode;
        var parentComputedStyle: ?*CssStyleDeclaration = null;
        if (parentNode != null and parentNode.?.nodeType == 1) {
            const parentElement: *Element = @fieldParentPtr(Element, "node", parentNode.?);
            const parentHtmlElement: *HtmlElement = @fieldParentPtr(HtmlElement, "element", parentElement);
            parentComputedStyle = try parentHtmlElement.getComputedStyle();
        }

        if (parentComputedStyle != null) {
            // Apply inherited styles
            try self.computedStyle.?.setProperty("color", parentComputedStyle.?.getPropertyValue("color"), parentComputedStyle.?.getPropertyPriority("color"));
            try self.computedStyle.?.setProperty("background-color", parentComputedStyle.?.getPropertyValue("background-color"), parentComputedStyle.?.getPropertyPriority("background-color"));
        } else {
            // TODO: Parse the color and rewrite it in rgb/rgba format
            std.debug.print("TODO: Need to convert {s} and {s} to rgb/rgba\n", .{ self.specifiedStyle.?.getPropertyValue("color"), self.specifiedStyle.?.getPropertyValue("background-color") });
            try self.computedStyle.?.setProperty("color", "rgb(0, 0, 0)", .Unimportant);
            try self.computedStyle.?.setProperty("background-color", "rgba(0, 0, 0, 0)", .Unimportant);
        }

        return self.computedStyle.?;
    }

    pub fn getUsedStyle(self: *HtmlElement) anyerror!*CssStyleDeclaration {
        if (self.usedStyle != null) return self.usedStyle.?;

        const computedStyle = try self.getComputedStyle();

        self.usedStyle = try self.allocator.create(CssStyleDeclaration);
        self.usedStyle.?.* = CssStyleDeclaration.init(self.allocator);

        const parentNode: ?*Node = self.element.node.parentNode;
        var parentUsedStyle: ?*CssStyleDeclaration = null;
        if (parentNode != null and parentNode.?.nodeType == 1) {
            const parentElement: *Element = @fieldParentPtr(Element, "node", parentNode.?);
            const parentHtmlElement: *HtmlElement = @fieldParentPtr(HtmlElement, "element", parentElement);
            parentUsedStyle = try parentHtmlElement.getUsedStyle();
        }
        var parent_width: f64 = 640;
        if (parentUsedStyle != null) {
            const parent_width_str = parentUsedStyle.?.getPropertyValue("width");
            parent_width = try std.fmt.parseFloat(f64, parent_width_str[0 .. parent_width_str.len - 2]);
        }
        var parent_height: f64 = 480;
        if (parentUsedStyle != null) {
            const parent_height_str = parentUsedStyle.?.getPropertyValue("height");
            parent_height = try std.fmt.parseFloat(f64, parent_height_str[0 .. parent_height_str.len - 2]);
        }

        var width_str = computedStyle.getPropertyValue("width");
        if (width_str[width_str.len - 1] == '%') {
            const float_val = try std.fmt.parseFloat(f64, width_str[0 .. width_str.len - 1]);
            var new_width_str = try std.fmt.allocPrint(self.allocator, "{d}px", .{parent_width * float_val / 100.0});
            try self.usedStyle.?.setProperty("width", new_width_str, computedStyle.getPropertyPriority("width"));
            self.allocator.free(new_width_str);
        } else if (std.mem.eql(u8, "auto", width_str)) {
            if (parentUsedStyle != null) {
                try self.usedStyle.?.setProperty("width", parentUsedStyle.?.getPropertyValue("width"), parentUsedStyle.?.getPropertyPriority("width"));
            } else {
                var new_width_str = try std.fmt.allocPrint(self.allocator, "{d}px", .{parent_width});
                try self.usedStyle.?.setProperty("width", new_width_str, .Unimportant);
                self.allocator.free(new_width_str);
            }
        } else {
            try self.usedStyle.?.setProperty("width", width_str, computedStyle.getPropertyPriority("width"));
        }

        var height_str = computedStyle.getPropertyValue("height");
        if (height_str[height_str.len - 1] == '%') {
            const float_val = try std.fmt.parseFloat(f64, height_str[0 .. height_str.len - 1]);
            var new_height_str = try std.fmt.allocPrint(self.allocator, "{d}px", .{parent_height * float_val / 100.0});
            try self.usedStyle.?.setProperty("height", new_height_str, computedStyle.getPropertyPriority("height"));
            self.allocator.free(new_height_str);
        } else if (std.mem.eql(u8, "auto", height_str)) {
            if (parentUsedStyle != null) {
                try self.usedStyle.?.setProperty("height", parentUsedStyle.?.getPropertyValue("height"), parentUsedStyle.?.getPropertyPriority("height"));
            } else {
                var new_height_str = try std.fmt.allocPrint(self.allocator, "{d}px", .{parent_height});
                try self.usedStyle.?.setProperty("height", new_height_str, .Unimportant);
                self.allocator.free(new_height_str);
            }
        } else {
            try self.usedStyle.?.setProperty("height", height_str, computedStyle.getPropertyPriority("height"));
        }

        try self.usedStyle.?.setProperty("margin-top", computedStyle.getPropertyValue("margin-top"), computedStyle.getPropertyPriority("margin-top"));
        try self.usedStyle.?.setProperty("margin-bottom", computedStyle.getPropertyValue("margin-bottom"), computedStyle.getPropertyPriority("margin-bottom"));
        try self.usedStyle.?.setProperty("margin-left", computedStyle.getPropertyValue("margin-left"), computedStyle.getPropertyPriority("margin-left"));
        try self.usedStyle.?.setProperty("margin-right", computedStyle.getPropertyValue("margin-right"), computedStyle.getPropertyPriority("margin-right"));

        try self.usedStyle.?.setProperty("padding-top", computedStyle.getPropertyValue("padding-top"), computedStyle.getPropertyPriority("padding-top"));
        try self.usedStyle.?.setProperty("padding-bottom", computedStyle.getPropertyValue("padding-bottom"), computedStyle.getPropertyPriority("padding-bottom"));
        try self.usedStyle.?.setProperty("padding-left", computedStyle.getPropertyValue("padding-left"), computedStyle.getPropertyPriority("padding-left"));
        try self.usedStyle.?.setProperty("padding-right", computedStyle.getPropertyValue("padding-right"), computedStyle.getPropertyPriority("padding-right"));

        try self.usedStyle.?.setProperty("color", computedStyle.getPropertyValue("color"), computedStyle.getPropertyPriority("color"));
        try self.usedStyle.?.setProperty("background-color", computedStyle.getPropertyValue("background-color"), computedStyle.getPropertyPriority("background-color"));

        return self.usedStyle.?;
    }

    pub fn parse(allocator: *Allocator, file: []const u8) anyerror!*HtmlElement {
        var hasSpace: bool = false;
        var text: ArrayList(u8) = ArrayList(u8).init(allocator);
        defer text.deinit();

        var outerHTML: ArrayList(u8) = ArrayList(u8).init(allocator);
        defer outerHTML.deinit();

        var innerHTML: ArrayList(u8) = ArrayList(u8).init(allocator);
        defer innerHTML.deinit();

        var outerTag: ?[]const u8 = null;
        var outerTagName: ?[]const u8 = null;
        var nodeType: u4 = 1;
        var inTag: bool = false;
        var childNodes = ArrayList(*Node).init(allocator);
        var attributes: ArrayList(Attr) = ArrayList(Attr).init(allocator);
        var tagStart: u32 = 0;
        var tagNameEnd: ?usize = null;
        var attributeStart: ?usize = null;
        var attributeEnd: ?usize = null;
        var valueStart: ?usize = null;
        var valueEnd: ?usize = null;
        var attribute: ?Attr = null;
        var styleAttribute: ?*Attr = null;
        var i: u32 = 0;
        while (i < file.len) : (i += 1) {
            var char: []const u8 = file[i .. i + 1];
            const byte = file[i];
            if (!inTag) {
                if (byte == '<') {
                    if (outerTag != null) {
                        if (file.len > i + outerTagName.?.len + 2 and std.mem.eql(u8, "</", file[i .. i + 2]) and std.mem.eql(u8, outerTagName.?, file[i + 2 .. i + 2 + outerTagName.?.len]) and file[i + 1 + outerTagName.?.len + 1] == '>') {
                            for (file[i .. i + 1 + outerTagName.?.len + 2]) |tagEndByte| {
                                try outerHTML.append(tagEndByte);
                            }
                            break;
                        } else {
                            var element: *HtmlElement = try parse(allocator, file[i..]);
                            for (element.element.outerHTML) |insideElementByte| {
                                try outerHTML.append(insideElementByte);
                                try innerHTML.append(insideElementByte);
                            }
                            try childNodes.append(&element.element.node);
                            i += @intCast(u32, element.element.outerHTML.len) - 1;
                            continue;
                        }
                    } else {
                        try outerHTML.append(file[i]);
                        inTag = true;
                        tagStart = @intCast(u32, i);
                    }
                } else if (outerTag != null) {
                    var textObj: ?Text = try parseText(allocator, file[i..]);
                    if (textObj != null) {
                        var textMemory = try allocator.create(Text);
                        textMemory.* = textObj.?;
                        var textNode = &textMemory.node;
                        try childNodes.append(textNode);
                        i += @intCast(u32, textObj.?.node.textContent.?.len) - 1;
                        for (textObj.?.node.textContent.?) |textByte| {
                            try outerHTML.append(textByte);
                            try innerHTML.append(textByte);
                        }
                        continue;
                    }
                }
            } else { // inTag
                try outerHTML.append(file[i]);
                switch (byte) {
                    '!' => { // <!DOCTYPE html>
                        while (file[i] != '>') : (i += 1) {}
                        outerTagName = "html";
                        nodeType = 10;
                        break;
                    },
                    ' ' => {
                        if ((valueStart != null and valueEnd != null) or valueStart == null) {
                            if (tagNameEnd == null) {
                                tagNameEnd = i;
                            }
                            if (attributeStart != null) {
                                if (attributeEnd == null) {
                                    attributeEnd = i;
                                }
                                if (valueStart != null and valueEnd != null) {
                                    attribute = Attr{
                                        .name = try std.mem.dupe(allocator, u8, file[attributeStart.?..attributeEnd.?]),
                                        .value = try std.mem.dupe(allocator, u8, file[valueStart.?..valueEnd.?]),
                                    };
                                } else {
                                    attribute = Attr{
                                        .name = try std.mem.dupe(allocator, u8, file[attributeStart.?..attributeEnd.?]),
                                        .value = try std.mem.dupe(allocator, u8, ""),
                                    };
                                }
                                try attributes.append(attribute.?);
                                if (std.mem.eql(u8, "style", attribute.?.name)) {
                                    styleAttribute = &attribute.?;
                                }
                                attributeStart = null;
                                attributeEnd = null;
                                valueStart = null;
                                valueEnd = null;
                            }
                        }
                    },
                    '=' => {
                        if (attributeStart != null and attributeEnd == null) {
                            attributeEnd = i;
                        }
                    },
                    '"' => {
                        if (valueStart == null) {
                            valueStart = i + 1;
                        } else {
                            valueEnd = i;
                        }
                    },
                    '/' => {
                        // closing tag
                    },
                    '>' => {
                        if ((valueStart != null and valueEnd != null) or valueStart == null) {
                            if (tagNameEnd == null) {
                                tagNameEnd = i;
                            }
                            if (attributeStart != null) {
                                if (attributeEnd == null) {
                                    attributeEnd = i;
                                }
                                if (valueStart != null and valueEnd != null) {
                                    attribute = Attr{
                                        .name = try std.mem.dupe(allocator, u8, file[attributeStart.?..attributeEnd.?]),
                                        .value = try std.mem.dupe(allocator, u8, file[valueStart.?..valueEnd.?]),
                                    };
                                } else {
                                    attribute = Attr{
                                        .name = try std.mem.dupe(allocator, u8, file[attributeStart.?..attributeEnd.?]),
                                        .value = try std.mem.dupe(allocator, u8, ""),
                                    };
                                }
                                try attributes.append(attribute.?);
                                if (std.mem.eql(u8, "style", attribute.?.name)) {
                                    styleAttribute = &attributes.items[attributes.items.len - 1];
                                }
                                attributeStart = null;
                                attributeEnd = null;
                                valueStart = null;
                                valueEnd = null;
                            }
                        }

                        inTag = false;
                        if (file[tagStart + 1] != '/') {
                            if (tagNameEnd == null) {
                                tagNameEnd = i;
                            }
                            if (outerTag == null) {
                                outerTag = file[tagStart .. i + 1];
                                outerTagName = file[tagStart + 1 .. tagNameEnd.?];
                                if (std.mem.eql(u8, "img", outerTagName.?)) {
                                    break;
                                } else if (std.mem.eql(u8, "br", outerTagName.?)) {
                                    break;
                                }
                            }
                        }
                    },
                    else => {
                        if (tagNameEnd != null and attributeStart == null) {
                            attributeStart = i;
                        }
                    },
                }
            }
        }

        for (childNodes.items) |node| {
            // add text content to innerText
            if (node.textContent) |nodeText| {
                var first: ?usize = null;
                var last: ?usize = null;
                for (nodeText) |byte, j| {
                    if (byte != ' ' and byte != '\n') {
                        if (first == null) {
                            first = j;
                        }
                        last = j;
                    }
                }
                if (first) |nonNullFirst| {
                    for (nodeText[nonNullFirst .. last.? + 1]) |innerTextByte| {
                        try text.append(innerTextByte);
                    }
                }
            }
        }

        var elementStyle: *CssStyleDeclaration = undefined;
        if (styleAttribute != null) {
            elementStyle = try CssParser.parseStyleDeclaration(allocator, styleAttribute.?.value);
        } else {
            elementStyle = try allocator.create(CssStyleDeclaration);
            elementStyle.* = CssStyleDeclaration.init(allocator);
        }
        errdefer allocator.destroy(elementStyle);
        errdefer elementStyle.deinit();

        var elementMemory = try allocator.create(HtmlElement);
        elementMemory.* = HtmlElement{
            .allocator = allocator,
            .element = Element{
                .attributes = attributes,
                .node = Node{
                    .eventTarget = try EventTarget.init(allocator),
                    .isConnected = true,
                    .nodeName = try std.ascii.allocUpperString(allocator, outerTagName.?),
                    .nodeType = nodeType,
                    .childNodes = childNodes,
                },
                .outerHTML = try allocator.dupe(u8, outerHTML.items),
                .innerHTML = try allocator.dupe(u8, innerHTML.items),
            },
            .innerText = try allocator.dupe(u8, text.items),
            .declaredStyle = elementStyle,
            .cascade = null,
            .specifiedStyle = null,
            .computedStyle = null,
            .usedStyle = null,
        };

        for (childNodes.items) |node| {
            node.parentNode = &elementMemory.element.node;
        }

        return elementMemory;
    }
};

test "A simple body with just text inside has correct innerText and a text child node" {
    var htmlElement: *HtmlElement = try HtmlElement.parse(testing.allocator,
        \\    <body>
        \\        Welcome to Zigrowser.
        \\    </body>
    );
    defer htmlElement.deinit();

    try expect(std.mem.eql(u8, "Welcome to Zigrowser.", htmlElement.innerText));
    try expect(std.mem.eql(u8, "<body>\n        Welcome to Zigrowser.\n    </body>", htmlElement.element.outerHTML));
    try expect(std.mem.eql(u8, "\n        Welcome to Zigrowser.\n    ", htmlElement.element.innerHTML));
    try expectEqual(@intCast(usize, 1), htmlElement.element.node.childNodes.items.len);
}

test "An HTML element" {
    var htmlElement: *HtmlElement = try HtmlElement.parse(testing.allocator,
        \\<html>
        \\    <body>
        \\        Welcome to Zigrowser.
        \\    </body>
        \\</html>
    );
    defer htmlElement.deinit();

    try expect(std.mem.eql(u8, "<html>\n    <body>\n        Welcome to Zigrowser.\n    </body>\n</html>", htmlElement.element.outerHTML));
    try expect(std.mem.eql(u8, "\n    <body>\n        Welcome to Zigrowser.\n    </body>\n", htmlElement.element.innerHTML));
    try expectEqual(@intCast(usize, 3), htmlElement.element.node.childNodes.items.len);
}

test "HTML attributes" {
    var htmlElement: *HtmlElement = try HtmlElement.parse(testing.allocator,
        \\<div id="test" class="awesome" style="margin: 8px; border: 1px solid black"></div>
    );
    defer htmlElement.deinit();

    var foundId: ?[]u8 = null;
    var foundClass: ?[]u8 = null;
    var foundStyle: ?[]u8 = null;

    for (htmlElement.element.attributes.items) |attr| {
        if (std.mem.eql(u8, "id", attr.name)) {
            foundId = attr.value;
        } else if (std.mem.eql(u8, "class", attr.name)) {
            foundClass = attr.value;
        } else if (std.mem.eql(u8, "style", attr.name)) {
            foundStyle = attr.value;
        }
    }

    try expect(std.mem.eql(u8, "test", foundId.?));
    try expect(std.mem.eql(u8, "awesome", foundClass.?));
    try expect(std.mem.eql(u8, "margin: 8px; border: 1px solid black", foundStyle.?));
}
