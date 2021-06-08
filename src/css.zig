const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
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
    const This = @This();

    fn noOpDeinit(this: *This) void {}

    getRulesFn: fn (this: *This, node: *Node, allocator: *Allocator) anyerror!ArrayList(Rule),
    deinitFn: fn (this: *This) void = noOpDeinit,

    pub fn getRules(this: *This, node: *Node, allocator: *Allocator) anyerror!ArrayList(Rule) {
        return this.getRulesFn(this, node, allocator);
    }

    pub fn deinit(this: *This) void {
        this.deinitFn(this);
    }
};

pub const UserAgentCSSRuleSet = struct {
    fn getRules(this: *RuleSet, node: *Node, allocator: *Allocator) anyerror!ArrayList(Rule) {

        // TODO: Make this better somehow... it's really ugly
        var rules: ArrayList(Rule) = ArrayList(Rule).init(allocator);

        // This represents the default user-agent rule of "body { margin: 8px }"
        if (std.mem.eql(u8, "BODY", node.nodeName)) {
            try rules.append(Rule{
                .property = "margin-top",
                .value = CSSValue{
                    .length = CSSLengthType{
                        .value = .{ .int = 8 },
                        .unit = CSSLengthUnit.px,
                    },
                },
            });
            try rules.append(Rule{
                .property = "margin-left",
                .value = CSSValue{
                    .length = CSSLengthType{
                        .value = .{ .int = 8 },
                        .unit = CSSLengthUnit.px,
                    },
                },
            });
            try rules.append(Rule{
                .property = "margin-bottom",
                .value = CSSValue{
                    .length = CSSLengthType{
                        .value = .{ .int = 8 },
                        .unit = CSSLengthUnit.px,
                    },
                },
            });
            try rules.append(Rule{
                .property = "margin-right",
                .value = CSSValue{
                    .length = CSSLengthType{
                        .value = .{ .int = 8 },
                        .unit = CSSLengthUnit.px,
                    },
                },
            });
        }
        return rules;
    }

    ruleSet: RuleSet = RuleSet{
        .getRulesFn = getRules,
    },
};

pub const GenericCSSRuleSet = struct {
    fn getRules(this: *RuleSet, node: *Node, allocator: *Allocator) anyerror!ArrayList(Rule) {
        var rules: ArrayList(Rule) = ArrayList(Rule).init(allocator);

        // TODO: Don't put this here but give functions to GenericCSSRuleSet that allow the rules to be added
        //
        // body { background-color: #131315; color: white }
        //
        // Also, rename "Rule" to something like "KeyValue" or something and "Rule" should really include the
        // full description of what it applies to (tag, class, descendent, etc.) along with the key-value pair
        //
        // Then this getRules can search those for applicable rules based on the criteria of the given node
        // and return those key-value pairs

        var descendentOfBody: bool = false;
        var currentNode: ?*Node = node;
        while (currentNode != null) : (currentNode = currentNode.?.parentNode) {
            if (std.mem.eql(u8, "BODY", currentNode.?.nodeName)) {
                descendentOfBody = true;
                break;
            }
        }
        if (descendentOfBody) {
            try rules.append(Rule{
                .property = "background-color",
                .value = CSSValue{
                    .color = CSSColor{
                        .rgba = CSSRGBAColor{
                            .r = 19,
                            .g = 19,
                            .b = 21,
                            .a = 255,
                        },
                    },
                },
            });
            try rules.append(Rule{
                .property = "color",
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
            });
        }

        return rules;
    }
    ruleSet: RuleSet = RuleSet{
        .getRulesFn = getRules,
    },
};

pub const CompositeCSSRuleSet = struct {
    pub fn init(allocator: *Allocator) !CompositeCSSRuleSet {
        return CompositeCSSRuleSet{
            .allocator = allocator,
            .ruleSets = ArrayList(*RuleSet).init(allocator),
        };
    }

    pub fn deinit(this: *RuleSet) void {
        var composite: *CompositeCSSRuleSet = @fieldParentPtr(CompositeCSSRuleSet, "ruleSet", this);
        for (composite.ruleSets.items) |ruleSet, i| {
            composite.allocator.destroy(ruleSet);
        }
        composite.ruleSets.deinit();
        composite.allocator.destroy(composite);
    }

    pub fn addRuleSet(this: *CompositeCSSRuleSet, ruleSet: *RuleSet) !void {
        try this.ruleSets.append(ruleSet);
    }

    fn getRules(this: *RuleSet, node: *Node, allocator: *Allocator) anyerror!ArrayList(Rule) {
        var composite: *CompositeCSSRuleSet = @fieldParentPtr(CompositeCSSRuleSet, "ruleSet", this);
        var rules: ArrayList(Rule) = ArrayList(Rule).init(allocator);

        for (composite.ruleSets.items) |ruleSet, i| {
            var ruleSetRules: ArrayList(Rule) = try ruleSet.getRules(node, allocator);
            for (ruleSetRules.items) |rule| {
                try rules.append(rule);
            }
            ruleSetRules.deinit();
        }
        return rules;
    }

    allocator: *Allocator,
    ruleSets: ArrayList(*RuleSet),
    ruleSet: RuleSet = RuleSet{
        .getRulesFn = CompositeCSSRuleSet.getRules,
        .deinitFn = CompositeCSSRuleSet.deinit,
    },
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
