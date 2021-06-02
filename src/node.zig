const std = @import("std");
const ArrayList = std.ArrayList;

const EventTarget = @import("eventtarget.zig");

const Document = @import("document.zig");

const Node = @This();

eventTarget: EventTarget,

baseURI: ?[]u8 = null,

childNodes: ArrayList(*Node),

firstChild: ?*Node = null,

isConnected: bool,

lastChild: ?*Node = null,

nextSibling: ?*Node = null,

nodeName: []const u8,

nodeType: u4,

nodeValue: ?[]const u8 = null,

ownerDocument: ?*Document = null,

parentNode: ?*Node = null,

// parentElement: ?Element,

previousSibling: ?*Node = null,

textContent: ?[]const u8 = null,

pub fn setOwnerDocument(node: *Node, document: *Document) anyerror!void {
    node.ownerDocument = document;
    for (node.childNodes.items) |child| {
        try child.setOwnerDocument(document);
    }
}
