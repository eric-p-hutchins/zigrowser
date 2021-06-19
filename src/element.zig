const std = @import("std");
const ArrayList = std.ArrayList;

const Node = @import("node.zig");

const Element = @This();

const Attr = @import("attr.zig");

attributes: ArrayList(Attr),

node: Node,

innerHTML: []u8,

outerHTML: []u8,

pub fn getAttribute(this: *Element, attribute: []const u8) []const u8 {
    for (this.attributes.items) |attr| {
        if (std.mem.eql(u8, attribute, attr.name)) {
            return attr.value;
        }
    }
    return "";
}
