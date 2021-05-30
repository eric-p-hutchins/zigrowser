const EventTarget = @import("eventtarget.zig");

const Node = @This();

eventTarget: EventTarget,

baseURI: ?[]u8 = null,

childNodes: []Node = &[_]Node{},

firstChild: ?*Node = null,

isConnected: bool,

lastChild: ?*Node = null,

nextSibling: ?*Node = null,

nodeName: []const u8,

nodeType: u4,

nodeValue: ?[]const u8 = null,

// ownerDocument: ?Document,

parentNode: ?*Node = null,

// parentElement: ?Element,

previousSibling: ?*Node = null,

textContent: ?[]const u8 = null,
