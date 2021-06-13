const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const EventTarget = @import("eventtarget.zig");
const Node = @import("node.zig");
const Element = @import("element.zig");

const HtmlElement = @import("html.zig").HtmlElement;

const CssRuleSet = @import("css.zig").RuleSet;
const CssDeclaration = @import("css.zig").Declaration;
const CssValue = @import("css.zig").CssValue;
const CssColor = @import("css.zig").CssColor;
const CssRGBAColor = @import("css.zig").CssRGBAColor;
const CssLengthType = @import("css.zig").CssLengthType;
const CssLengthUnit = @import("css.zig").CssLengthUnit;
const CssParser = @import("css.zig").CssParser;

const UserAgentCssRuleSet = @import("css.zig").UserAgentCssRuleSet;
const GenericCssRuleSet = @import("css.zig").GenericCssRuleSet;
const CompositeCssRuleSet = @import("css.zig").CompositeCssRuleSet;

const Document = @This();

const testing = std.testing;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;

doctypeElement: ?*HtmlElement,
htmlElement: *HtmlElement,

node: Node,

head: *HtmlElement,
body: *HtmlElement,

cssRuleSet: *CssRuleSet,

fn findStyleElements(allocator: *Allocator, node: *Node) anyerror!*ArrayList(*const Node) {
    var nodes: *ArrayList(*const Node) = try allocator.create(ArrayList(*const Node));
    nodes.* = ArrayList(*const Node).init(allocator);
    // var nodes: ArrayList(*const Node) = ArrayList(*const Node).init(allocator);

    if (std.mem.eql(u8, "STYLE", node.nodeName)) {
        try nodes.append(node);
        return nodes;
    }

    for (node.childNodes.items) |child| {
        const childNodes: *ArrayList(*const Node) = try findStyleElements(allocator, child);
        for (childNodes.items) |styleNode| {
            try nodes.append(styleNode);
        }
        childNodes.deinit();
        allocator.destroy(childNodes);
    }
    return nodes;
}

pub fn init(allocator: *Allocator, string: []const u8) !*Document {
    var inTag: bool = false;
    var tagStart: u32 = 0;
    var doctypeElement: ?*HtmlElement = null;
    var documentElement: ?*HtmlElement = null;
    var head: ?*HtmlElement = null;
    var body: ?*HtmlElement = null;
    documentElement = try HtmlElement.parse(allocator, string);
    if (documentElement != null and documentElement.?.element.node.nodeType == 10) {
        doctypeElement = documentElement;
        documentElement = try HtmlElement.parse(allocator, string[documentElement.?.element.outerHTML.len..]);
    }
    if (documentElement != null) {
        for (documentElement.?.element.node.childNodes.items) |node| {
            if (std.mem.eql(u8, "HEAD", node.nodeName)) {
                var headElement: *Element = @fieldParentPtr(Element, "node", node);
                var headHtmlElement: *HtmlElement = @fieldParentPtr(HtmlElement, "element", headElement);
                head = headHtmlElement;
            }
            if (std.mem.eql(u8, "BODY", node.nodeName)) {
                var bodyElement: *Element = @fieldParentPtr(Element, "node", node);
                var bodyHtmlElement: *HtmlElement = @fieldParentPtr(HtmlElement, "element", bodyElement);
                body = bodyHtmlElement;
            }
        }
    }

    var ruleSet: *CompositeCssRuleSet = try allocator.create(CompositeCssRuleSet);
    ruleSet.* = try CompositeCssRuleSet.init(allocator);

    var userAgentRuleSet = try allocator.create(UserAgentCssRuleSet);
    userAgentRuleSet.* = UserAgentCssRuleSet{};
    try ruleSet.addRuleSet(&userAgentRuleSet.ruleSet);

    var styleElements = try findStyleElements(allocator, &documentElement.?.element.node);

    for (styleElements.items) |styleNode| {
        var element = @fieldParentPtr(Element, "node", styleNode);
        var elementRuleSet = try CssParser.parse(allocator, element.innerHTML);
        try ruleSet.addRuleSet(elementRuleSet);
    }

    styleElements.deinit();
    allocator.destroy(styleElements);

    const document: *Document = try allocator.create(Document);
    document.* = Document{
        .cssRuleSet = &ruleSet.ruleSet,
        .doctypeElement = doctypeElement,
        .htmlElement = documentElement.?,
        .node = Node{
            .eventTarget = try EventTarget.init(allocator),
            .isConnected = true,
            .nodeName = "#document",
            .nodeType = 9,
            .childNodes = ArrayList(*Node).init(allocator),
            .ownerDocument = document,
        },
        .head = head.?,
        .body = body.?,
    };
    try document.htmlElement.element.node.setOwnerDocument(document);
    return document;
}

pub fn deinit(self: *Document, allocator: *Allocator) void {
    if (self.doctypeElement != null) {
        self.doctypeElement.?.deinit();
    }
    self.htmlElement.deinit();
    self.cssRuleSet.deinit();
    allocator.destroy(self);
}

test "document initialization" {
    var html = "<!DOCTYPE html><html><head><title>Test</title></head><body></body></html>";
    var document: *Document = try Document.init(testing.allocator, html);
    defer document.deinit(testing.allocator);

    try expect(document.node.isConnected);
    try expectEqualStrings("#document", document.node.nodeName);
}

test "A simple page with just text in the body has correct innerText and a text child node" {
    var document: *Document = try Document.init(std.testing.allocator,
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

    try expectEqualStrings("HEAD", document.head.element.node.nodeName);
    try expectEqual(@intCast(usize, 3), document.head.element.node.childNodes.items.len);

    try expectEqual(@intCast(usize, 3), document.head.element.node.childNodes.items[0].*.nodeType);
    try expectEqualStrings("#text", document.head.element.node.childNodes.items[0].*.nodeName);
    try expectEqualStrings("\n        ", document.head.element.node.childNodes.items[0].*.textContent.?);

    try expectEqual(@intCast(usize, 1), document.head.element.node.childNodes.items[1].*.nodeType);
    try expectEqualStrings("TITLE", document.head.element.node.childNodes.items[1].*.nodeName);
    try expectEqualStrings("Welcome to Zigrowser", document.head.element.node.childNodes.items[1].*.childNodes.items[0].*.textContent.?);

    try expectEqual(@intCast(usize, 3), document.head.element.node.childNodes.items[2].*.nodeType);
    try expectEqualStrings("#text", document.head.element.node.childNodes.items[2].*.nodeName);
    try expectEqualStrings("\n    ", document.head.element.node.childNodes.items[2].*.textContent.?);

    try expect(std.mem.eql(u8, "Welcome to Zigrowser.", document.body.innerText));
    try expectEqual(@intCast(usize, 1), document.body.element.node.childNodes.items.len);
}
