const std = @import("std");

const expect = std.testing.expect;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const Element = struct {
    const This = @This();

    innerText: []u8,

    pub fn free(this: This, allocator: *Allocator) void {
        allocator.free(this.innerText);
    }

    pub fn parse(allocator: *Allocator, file: [:0]const u8) !Element {
        var hasSpace: bool = false;
        var text: ArrayList(u8) = ArrayList(u8).init(allocator);
        defer text.deinit();

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
        return Element{ .innerText = try allocator.dupe(u8, text.items) };
    }
};

test "The body is just the text inside when there is nothing else" {
    const html: Element = try HTML.parse(std.testing.allocator,
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
    defer std.testing.allocator.free(html.innerText);

    expect(std.mem.eql(u8, "Welcome to Zigrowser.", html.innerText));
}
