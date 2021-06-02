const std = @import("std");
const testing = std.testing;
const expectEqual = testing.expectEqual;

const Node = @import("node.zig");

pub const CSSDataType = enum {
    length,
    color,
    textAlign,
};

pub const CSSLengthUnit = enum {
    percent,
    px,
};

pub const CSSColorKeyword = enum {
    white,
};

// Percentages or float values like 50% or 0.5 should be mapped to u8 values (50% = 0x80, 0.25 = 0x40). alpha
// should default to 0xFF when unspecified by the CSS source
// Keywords also need to be mapped so that 'white' comes in as .{ .r = 255, .g = 255, .b = 255, .a = 255 }
pub const CSSRGBAColor = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

pub const CSSTextAlign = enum {
    left,
    right,
    center,
};

pub const CSSColor = union(enum) {
    rgba: CSSRGBAColor,
};

pub const CSSNumber = union(enum) {
    int: i64,
    float: f64,
};

pub const CSSLengthType = struct {
    value: CSSNumber,
    unit: CSSLengthUnit,
};

pub const CSSValue = union(CSSDataType) {
    length: CSSLengthType,
    color: CSSColor,
    textAlign: CSSTextAlign,
};

pub const Rule = struct {
    property: []const u8,
    value: CSSValue,
};

pub const RuleSet = struct {
    getRules: fn (node: *Node) anyerror![]const Rule,
};

test "CSS length" {
    const rule: Rule = Rule{
        .property = "margin-top",
        .value = CSSValue{
            .length = CSSLengthType{
                .value = .{ .int = 8 },
                .unit = CSSLengthUnit.px,
            },
        },
    };

    var isIt8Pixels: bool = false;
    switch (rule.value) {
        CSSDataType.length => |length| {
            switch (length.unit) {
                CSSLengthUnit.percent => {},
                CSSLengthUnit.px => {
                    switch (length.value) {
                        CSSNumber.int => |int_length| if (int_length == 8) {
                            isIt8Pixels = true;
                        },
                        CSSNumber.float => |float_length| {},
                    }
                },
            }
        },
        else => {},
    }
    expectEqual(true, isIt8Pixels);
}

test "CSS color" {
    const rule: Rule = Rule{
        .property = "background-color",
        .value = CSSValue{
            .color = CSSColor{
                .rgba = CSSRGBAColor{
                    .r = 255,
                    .g = 255,
                    .b = 255,
                    .a = 255,
                },
            },
        },
    };

    var isItWhite: bool = false;
    switch (rule.value) {
        CSSDataType.color => |color| {
            switch (color) {
                CSSColor.rgba => |rgba| {
                    if (rgba.r == 255 and rgba.g == 255 and rgba.b == 255 and rgba.a == 255) {
                        isItWhite = true;
                    }
                },
            }
        },
        else => {},
    }
    expectEqual(true, isItWhite);
}

test "CSS text-align" {
    const rule: Rule = Rule{
        .property = "text-align",
        .value = CSSValue{
            .textAlign = CSSTextAlign.center,
        },
    };

    expectEqual(true, switch (rule.value) {
        CSSDataType.textAlign => |textAlign| if (textAlign == CSSTextAlign.center) true else false,
        else => false,
    });
}
