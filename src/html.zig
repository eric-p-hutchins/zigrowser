const std = @import("std");
const testing = std.testing;
const expect = testing.expect;

const Node = @import("node.zig");
const EventTarget = @import("eventtarget.zig");
const Element = @import("element.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const HTMLElement = struct {
    const This = @This();

    element: Element,

    innerText: []u8,

    pub fn free(this: *This, allocator: *Allocator) void {
        allocator.free(this.innerText);
        allocator.destroy(this.element.node.childNodes.items[0]);
        this.element.node.childNodes.deinit();
    }

    pub fn parse(allocator: *Allocator, file: [:0]const u8) !HTMLElement {
        var hasSpace: bool = false;
        var text: ArrayList(u8) = ArrayList(u8).init(allocator);
        defer text.deinit();

        var inTag: bool = false;
        var childNodes = ArrayList(*Node).init(allocator);
        var pastLeadingWhitespace: bool = false;
        var tagStart: u32 = 0;
        var inBody: bool = false;
        for (file) |byte, i| {
            if (!inTag) {
                if (byte == '<') {
                    inTag = true;
                    tagStart = @intCast(u32, i);
                    if (inBody) {
                        inBody = false;
                    }
                } else if (inBody and pastLeadingWhitespace) {
                    if ((byte == ' ' or byte == '\n') and text.items.len > 0 and text.items[text.items.len - 1] != ' ') {
                        hasSpace = true;
                    } else if (byte != ' ' and byte != '\n') {
                        if (hasSpace) {
                            try text.append(' ');
                            hasSpace = false;
                        }
                        try text.append(byte);
                    }
                } else if (inBody and byte != ' ' and byte != '\n') {
                    try text.append(byte);
                    pastLeadingWhitespace = true;
                }
            } else {
                if (byte == '>') {
                    inTag = false;
                    if (std.mem.eql(u8, file[tagStart .. i + 1], "<body>")) {
                        inBody = true;
                    }
                }
            }
        }
        var textNode = try allocator.create(Node);
        textNode.* = Node{
            .eventTarget = try EventTarget.init(allocator),
            .isConnected = true,
            .nodeName = "#text",
            .nodeType = 3,
            .childNodes = ArrayList(*Node).init(allocator),
        };
        try childNodes.append(textNode);
        return HTMLElement{
            .element = Element{
                .node = Node{
                    .eventTarget = try EventTarget.init(allocator),
                    .isConnected = true,
                    .nodeName = "BODY",
                    .nodeType = 1,
                    .childNodes = childNodes,
                },
            },
            .innerText = try allocator.dupe(u8, text.items),
        };
    }
};

test "The body is just the text inside when there is nothing else" {
    var html: HTMLElement = try HTMLElement.parse(testing.allocator,
        \\<!DOCTYPE html>
        \\<html>
        \\    <head>
        \\        <title>Welcome to Zigrowser</title>
        \\    </head>
        \\    <body>
        \\        Welcome to Zigrowser.
        \\    </body>
        \\</html>
    );
    defer html.free(testing.allocator);

    expect(std.mem.eql(u8, "Welcome to Zigrowser.", html.innerText));
}
