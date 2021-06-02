const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const EventTarget = @import("eventtarget.zig");
const Node = @import("node.zig");
const Element = @import("element.zig");

const HTMLElement = @import("html.zig").HTMLElement;

const Document = @This();

const testing = std.testing;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;

doctypeElement: ?*HTMLElement,
htmlElement: *HTMLElement,

node: Node,

head: *HTMLElement,
body: *HTMLElement,

pub fn init(allocator: *Allocator, string: []const u8) !Document {
    var inTag: bool = false;
    var tagStart: u32 = 0;
    var doctypeElement: ?*HTMLElement = null;
    var documentElement: ?*HTMLElement = null;
    var head: ?*HTMLElement = null;
    var body: ?*HTMLElement = null;
    documentElement = try HTMLElement.parse(allocator, string);
    if (documentElement != null and documentElement.?.element.node.nodeType == 10) {
        doctypeElement = documentElement;
        documentElement = try HTMLElement.parse(allocator, string[documentElement.?.element.outerHTML.len..]);
    }
    if (documentElement != null) {
        for (documentElement.?.element.node.childNodes.items) |node| {
            if (std.mem.eql(u8, "HEAD", node.nodeName)) {
                var headElement: *Element = @fieldParentPtr(Element, "node", node);
                var headHtmlElement: *HTMLElement = @fieldParentPtr(HTMLElement, "element", headElement);
                head = headHtmlElement;
            }
            if (std.mem.eql(u8, "BODY", node.nodeName)) {
                var bodyElement: *Element = @fieldParentPtr(Element, "node", node);
                var bodyHtmlElement: *HTMLElement = @fieldParentPtr(HTMLElement, "element", bodyElement);
                body = bodyHtmlElement;
            }
        }
    }
    return Document{
        .doctypeElement = doctypeElement,
        .htmlElement = documentElement.?,
        .node = Node{
            .eventTarget = try EventTarget.init(allocator),
            .isConnected = true,
            .nodeName = "#document",
            .nodeType = 9,
            .childNodes = ArrayList(*Node).init(allocator),
        },
        .head = head.?,
        .body = body.?,
    };
}

pub fn deinit(self: *Document, allocator: *Allocator) void {
    if (self.doctypeElement != null) {
        self.doctypeElement.?.free(allocator);
    }
    // self.head.free(allocator);
    // self.body.free(allocator);
    self.htmlElement.free(allocator);
}

test "document initialization" {
    var html = "<!DOCTYPE html><html><head><title>Test</title></head><body></body></html>";
    var document: Document = try Document.init(testing.allocator, html);
    defer document.deinit(testing.allocator);
    expect(document.node.isConnected);
    expectEqualStrings("#document", document.node.nodeName);
}

test "A simple page with just text in the body has correct innerText and a text child node" {
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

    expectEqualStrings("HEAD", document.head.element.node.nodeName);
    expectEqual(@intCast(usize, 3), document.head.element.node.childNodes.items.len);

    expectEqual(@intCast(usize, 3), document.head.element.node.childNodes.items[0].*.nodeType);
    expectEqualStrings("#text", document.head.element.node.childNodes.items[0].*.nodeName);
    expectEqualStrings("\n        ", document.head.element.node.childNodes.items[0].*.textContent.?);

    expectEqual(@intCast(usize, 1), document.head.element.node.childNodes.items[1].*.nodeType);
    expectEqualStrings("TITLE", document.head.element.node.childNodes.items[1].*.nodeName);
    expectEqualStrings("Welcome to Zigrowser", document.head.element.node.childNodes.items[1].*.childNodes.items[0].*.textContent.?);

    expectEqual(@intCast(usize, 3), document.head.element.node.childNodes.items[2].*.nodeType);
    expectEqualStrings("#text", document.head.element.node.childNodes.items[2].*.nodeName);
    expectEqualStrings("\n    ", document.head.element.node.childNodes.items[2].*.textContent.?);

    expect(std.mem.eql(u8, "Welcome to Zigrowser.", document.body.innerText));
    expectEqual(@intCast(usize, 1), document.body.element.node.childNodes.items.len);
}
