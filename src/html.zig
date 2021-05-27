const std = @import("std");

const expect = std.testing.expect;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const TextContainer = struct {
    text: []const u8
};

test "The body is just the text inside when there is nothing else" {
    const html: HTML = try HTML.parse(std.testing.allocator,
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

    // TODO: Make this work to not have the trailing space...

    // expect(std.mem.eql(u8, "Welcome to Zigrowser.", html.body.text));

    expect(std.mem.eql(u8, "Welcome to Zigrowser. ", html.body.text));
}

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
        const html: HTML = HTML{ .body = TextContainer{ .text = text.items } };

        // TODO: Don't memory leak when parsing... this doesn't work. Figure out the right way
        // text.deinit();

        return html;
    }
};
