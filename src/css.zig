const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const testing = std.testing;
const expectEqual = testing.expectEqual;

const Node = @import("node.zig");

pub const CssDataType = enum {
    length,
    color,
    textAlign,
};

pub const CssLengthUnit = enum {
    percent,
    px,
};

pub const CssColorKeyword = enum {
    white,
};

// Percentages or float values like 50% or 0.5 should be mapped to u8 values (50% = 0x80, 0.25 = 0x40). alpha
// should default to 0xFF when unspecified by the CSS source
// Keywords also need to be mapped so that 'white' comes in as .{ .r = 255, .g = 255, .b = 255, .a = 255 }
pub const CssRGBAColor = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

pub const CssTextAlign = enum {
    left,
    right,
    center,
};

pub const CssColor = union(enum) {
    rgba: CssRGBAColor,
};

pub const CssNumber = union(enum) {
    int: i64,
    float: f64,
};

pub const CssLengthType = struct {
    value: CssNumber,
    unit: CssLengthUnit,
};

pub const CssValue = union(CssDataType) {
    length: CssLengthType,
    color: CssColor,
    textAlign: CssTextAlign,
};

pub const Rule = struct {
    property: []const u8,
    value: CssValue,
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

pub const UserAgentCssRuleSet = struct {
    fn getRules(this: *RuleSet, node: *Node, allocator: *Allocator) anyerror!ArrayList(Rule) {

        // TODO: Make this better somehow... it's really ugly
        var rules: ArrayList(Rule) = ArrayList(Rule).init(allocator);

        // This represents the default user-agent rule of "body { margin: 8px }"
        if (std.mem.eql(u8, "BODY", node.nodeName)) {
            try rules.append(Rule{
                .property = "margin-top",
                .value = CssValue{
                    .length = CssLengthType{
                        .value = .{ .int = 8 },
                        .unit = CssLengthUnit.px,
                    },
                },
            });
            try rules.append(Rule{
                .property = "margin-left",
                .value = CssValue{
                    .length = CssLengthType{
                        .value = .{ .int = 8 },
                        .unit = CssLengthUnit.px,
                    },
                },
            });
            try rules.append(Rule{
                .property = "margin-bottom",
                .value = CssValue{
                    .length = CssLengthType{
                        .value = .{ .int = 8 },
                        .unit = CssLengthUnit.px,
                    },
                },
            });
            try rules.append(Rule{
                .property = "margin-right",
                .value = CssValue{
                    .length = CssLengthType{
                        .value = .{ .int = 8 },
                        .unit = CssLengthUnit.px,
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

pub const GenericCssRuleSet = struct {
    fn getRules(this: *RuleSet, node: *Node, allocator: *Allocator) anyerror!ArrayList(Rule) {
        var rules: ArrayList(Rule) = ArrayList(Rule).init(allocator);

        // TODO: Don't put this here but give functions to GenericCssRuleSet that allow the rules to be added
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
                .value = CssValue{
                    .color = CssColor{
                        .rgba = CssRGBAColor{
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
                .value = CssValue{
                    .color = CssColor{
                        .rgba = CssRGBAColor{
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

pub const CompositeCssRuleSet = struct {
    pub fn init(allocator: *Allocator) !CompositeCssRuleSet {
        return CompositeCssRuleSet{
            .allocator = allocator,
            .ruleSets = ArrayList(*RuleSet).init(allocator),
        };
    }

    pub fn deinit(this: *RuleSet) void {
        var composite: *CompositeCssRuleSet = @fieldParentPtr(CompositeCssRuleSet, "ruleSet", this);
        for (composite.ruleSets.items) |ruleSet, i| {
            composite.allocator.destroy(ruleSet);
        }
        composite.ruleSets.deinit();
        composite.allocator.destroy(composite);
    }

    pub fn addRuleSet(this: *CompositeCssRuleSet, ruleSet: *RuleSet) !void {
        try this.ruleSets.append(ruleSet);
    }

    fn getRules(this: *RuleSet, node: *Node, allocator: *Allocator) anyerror!ArrayList(Rule) {
        var composite: *CompositeCssRuleSet = @fieldParentPtr(CompositeCssRuleSet, "ruleSet", this);
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
        .getRulesFn = CompositeCssRuleSet.getRules,
        .deinitFn = CompositeCssRuleSet.deinit,
    },
};

test "CSS length" {
    const rule: Rule = Rule{
        .property = "margin-top",
        .value = CssValue{
            .length = CssLengthType{
                .value = .{ .int = 8 },
                .unit = CssLengthUnit.px,
            },
        },
    };

    var isIt8Pixels: bool = false;
    switch (rule.value) {
        CssDataType.length => |length| {
            switch (length.unit) {
                CssLengthUnit.percent => {},
                CssLengthUnit.px => {
                    switch (length.value) {
                        CssNumber.int => |int_length| if (int_length == 8) {
                            isIt8Pixels = true;
                        },
                        CssNumber.float => |float_length| {},
                    }
                },
            }
        },
        else => {},
    }
    try expectEqual(true, isIt8Pixels);
}

test "CSS color" {
    const rule: Rule = Rule{
        .property = "background-color",
        .value = CssValue{
            .color = CssColor{
                .rgba = CssRGBAColor{
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
        CssDataType.color => |color| {
            switch (color) {
                CssColor.rgba => |rgba| {
                    if (rgba.r == 255 and rgba.g == 255 and rgba.b == 255 and rgba.a == 255) {
                        isItWhite = true;
                    }
                },
            }
        },
        else => {},
    }
    try expectEqual(true, isItWhite);
}

test "CSS text-align" {
    const rule: Rule = Rule{
        .property = "text-align",
        .value = CssValue{
            .textAlign = CssTextAlign.center,
        },
    };

    try expectEqual(true, switch (rule.value) {
        CssDataType.textAlign => |textAlign| if (textAlign == CssTextAlign.center) true else false,
        else => false,
    });
}
