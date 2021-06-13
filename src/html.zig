const std = @import("std");
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

const Node = @import("node.zig");
const EventTarget = @import("eventtarget.zig");
const Element = @import("element.zig");

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

    pub fn deinit(this: *This) void {
        this.allocator.free(this.innerText);
        this.allocator.free(this.element.node.nodeName);
        this.allocator.free(this.element.outerHTML);
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
        var tagStart: u32 = 0;
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
            } else {
                try outerHTML.append(file[i]);
                try innerHTML.append(file[i]);
                if (byte == '>') {
                    inTag = false;
                    if (file[tagStart + 1] == '!') {
                        outerTagName = "html";
                        nodeType = 10;
                        break;
                    } else if (file[tagStart + 1] != '/') {
                        var tagNameEnd: usize = tagStart + 1;
                        while (file.len > tagNameEnd + 1 and file[tagNameEnd + 1] != ' ' and file[tagNameEnd + 1] != '>') : (tagNameEnd += 1) {}
                        if (outerTag == null) {
                            outerTag = file[tagStart .. i + 1];
                            outerTagName = file[tagStart + 1 .. tagNameEnd + 1];
                            if (std.mem.eql(u8, "img", outerTagName.?)) {
                                break;
                            } else if (std.mem.eql(u8, "br", outerTagName.?)) {
                                break;
                            }
                        }
                    }
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

        var elementMemory = try allocator.create(HtmlElement);
        elementMemory.* = HtmlElement{
            .allocator = allocator,
            .element = Element{
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

    try expectEqual(@intCast(usize, 3), htmlElement.element.node.childNodes.items.len);
}
