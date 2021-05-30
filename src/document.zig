const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const EventTarget = @import("eventtarget.zig");
const Node = @import("node.zig");

const HTMLElement = @import("html.zig").HTMLElement;

const Document = @This();

const testing = std.testing;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;

node: Node,

body: HTMLElement,

pub fn init(allocator: *Allocator, string: [:0]const u8) !Document {
    return Document{
        .node = Node{
            .eventTarget = try EventTarget.init(allocator),
            .isConnected = true,
            .nodeName = "#document",
            .nodeType = 9,
            .childNodes = ArrayList(*Node).init(allocator),
        },
        .body = try HTMLElement.parse(allocator, string),
    };
}

pub fn deinit(self: *Document, allocator: *Allocator) void {
    self.body.free(allocator);
}

test "document initialization" {
    var html = "<!DOCTYPE html><html><head><title>Test</title></head><body></body></html>";
    var document: Document = try Document.init(testing.allocator, html);
    defer document.deinit(testing.allocator);
    expect(document.node.isConnected);
    expectEqualStrings("#document", document.node.nodeName);
}

test "A simple body with just text inside has correct innerText and a text child node" {
    var document: Document = try Document.init(std.testing.allocator,
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
    defer document.deinit(testing.allocator);

    expect(std.mem.eql(u8, "Welcome to Zigrowser.", document.body.innerText));
    expectEqual(@intCast(usize, 1), document.body.element.node.childNodes.items.len);
}
