const std = @import("std");
const ArrayList = std.ArrayList;

const Node = @import("node.zig");

const Element = @This();

const Attr = @import("attr.zig");

attributes: ArrayList(Attr),

node: Node,

innerHTML: []u8,

outerHTML: []u8,
