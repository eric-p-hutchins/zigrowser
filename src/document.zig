const std = @import("std");
const Allocator = std.mem.Allocator;

const EventTarget = @import("eventtarget.zig");
const Node = @import("node.zig");

const Element = @import("html.zig").Element;

const Document = @This();

const testing = std.testing;
const expect = std.testing.expect;
const expectEqualStrings = std.testing.expectEqualStrings;

node: Node,

body: Element,

pub fn init(allocator: *Allocator, string: [:0]const u8) !Document {
    return Document{
        .node = Node{
            .eventTarget = try EventTarget.init(allocator),
            .isConnected = true,
            .nodeName = "#document",
            .nodeType = 9,
        },
        .body = try Element.parse(allocator, string),
    };
}

pub fn deinit(self: *Document, allocator: *Allocator) void {
    self.body.free(allocator);
}

test "document initialization" {
    var html = "<!DOCTYPE html><html><head><title>Test</title></head><body></body></html>";
    var document: Document = try Document.init(testing.allocator, html);
    expect(document.node.isConnected);
    expectEqualStrings("#document", document.node.nodeName);
}

test "The body is just the text inside when there is nothing else" {
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
    defer document.body.free(testing.allocator);

    expect(std.mem.eql(u8, "Welcome to Zigrowser.", document.body.innerText));
}
