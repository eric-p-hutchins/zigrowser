const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const TextContainer = struct {
    text: []const u8
};

pub const HTML = struct {
    body: TextContainer,

    pub fn parse(allocator: *Allocator, file: [:0]const u8) !HTML {
        var text: ArrayList(u8) = ArrayList(u8).init(allocator);
        var inTag: bool = false;
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
                        try text.append(' ');
                    } else if (byte != ' ' and byte != '\n') {
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
        return HTML{ .body = TextContainer{ .text = text.items } };
    }
};
