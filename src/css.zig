const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const testing = std.testing;
const expectEqual = testing.expectEqual;

const Node = @import("node.zig");

pub const CssValueType = enum {
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

pub const CssValue = union(CssValueType) {
    length: CssLengthType,
    color: CssColor,
    textAlign: CssTextAlign,
};

pub const Declaration = struct {
    property: []const u8,
    value: CssValue,
};

pub const CssParser = struct {
    pub fn parse(allocator: *Allocator, text: []const u8) !*RuleSet {
        var genericRuleSet = try GenericCssRuleSet.init(allocator);

        // TODO: Actually get this from parsing the style element
        try genericRuleSet.addDeclaration("BODY", Declaration{
            .property = "background-color",
            .value = CssValue{ .color = CssColor{ .rgba = CssRGBAColor{ .r = 19, .g = 19, .b = 21, .a = 255 } } },
        });
        try genericRuleSet.addDeclaration("BODY", Declaration{
            .property = "color",
            .value = CssValue{ .color = CssColor{ .rgba = CssRGBAColor{ .r = 255, .g = 255, .b = 255, .a = 255 } } },
        });

        return &genericRuleSet.ruleSet;
    }
};

test "CSS parser" {
    var ruleSet = try CssParser.parse(std.testing.allocator, "body{background-color: #131315;color:white}");
    defer ruleSet.deinit();
}

const SelectorToDeclarationMap = std.StringHashMap(ArrayList(Declaration));

pub const RuleSet = struct {
    const This = @This();

    fn noOpDeinit(this: *This) void {}

    getDeclarationsFn: fn (this: *This, node: *Node, allocator: *Allocator) anyerror!ArrayList(Declaration),
    deinitFn: fn (this: *This) void = noOpDeinit,

    /// Get the declarations that apply to the given node.
    ///
    /// For example, if the node is a body and this rule set has loaded a block that looks like:
    ///
    ///     body { prop1: value1; prop2: value2; }
    ///
    /// then the declarations for 'prop1' and 'prop2' should be returned because they apply to a body element
    pub fn getDeclarations(this: *This, node: *Node, allocator: *Allocator) anyerror!ArrayList(Declaration) {
        return this.getDeclarationsFn(this, node, allocator);
    }

    pub fn deinit(this: *This) void {
        this.deinitFn(this);
    }
};

pub fn intToPixels(length: i64) CssValue {
    return CssValue{
        .length = CssLengthType{
            .value = .{ .int = length },
            .unit = CssLengthUnit.px,
        },
    };
}

pub fn floatToPixels(length: f64) CssValue {
    return CssValue{
        .length = CssLengthType{
            .value = .{ .float = length },
            .unit = CssLengthUnit.px,
        },
    };
}

pub const UserAgentCssRuleSet = struct {
    fn getDeclarations(this: *RuleSet, node: *Node, allocator: *Allocator) anyerror!ArrayList(Declaration) {
        var declarations: ArrayList(Declaration) = ArrayList(Declaration).init(allocator);

        // This represents the default user-agent rule of "body { margin: 8px }"
        if (std.mem.eql(u8, "BODY", node.nodeName)) {
            try declarations.append(Declaration{ .property = "margin-top", .value = intToPixels(8) });
            try declarations.append(Declaration{ .property = "margin-left", .value = intToPixels(8) });
            try declarations.append(Declaration{ .property = "margin-bottom", .value = intToPixels(8) });
            try declarations.append(Declaration{ .property = "margin-right", .value = intToPixels(8) });
        }
        return declarations;
    }

    ruleSet: RuleSet = RuleSet{
        .getDeclarationsFn = getDeclarations,
    },
};

pub const GenericCssRuleSet = struct {
    allocator: *Allocator,
    selectorToDeclarationMap: SelectorToDeclarationMap,
    ruleSet: RuleSet = RuleSet{
        .getDeclarationsFn = getDeclarations,
        .deinitFn = deinit,
    },

    pub fn init(allocator: *Allocator) !*GenericCssRuleSet {
        var genericCssRuleSet = try allocator.create(GenericCssRuleSet);
        var selectorToDeclarationMap = SelectorToDeclarationMap.init(allocator);

        genericCssRuleSet.* = GenericCssRuleSet{
            .allocator = allocator,
            .selectorToDeclarationMap = selectorToDeclarationMap,
        };

        return genericCssRuleSet;
    }

    pub fn addDeclaration(this: *GenericCssRuleSet, selector: []const u8, declaration: Declaration) !void {
        var optionalDeclarations = this.selectorToDeclarationMap.get(selector);
        if (optionalDeclarations == null) {
            try this.selectorToDeclarationMap.put(selector, ArrayList(Declaration).init(this.allocator));
        }
        var declarations = this.selectorToDeclarationMap.get(selector).?;
        try declarations.append(declaration);
        try this.selectorToDeclarationMap.put(selector, declarations);
    }

    fn deinit(this: *RuleSet) void {
        const genericCssRuleSet: *GenericCssRuleSet = @fieldParentPtr(GenericCssRuleSet, "ruleSet", this);

        var iterator = genericCssRuleSet.selectorToDeclarationMap.valueIterator();
        var list: ?*ArrayList(Declaration) = iterator.next();
        while (list != null) : (list = iterator.next()) {
            list.?.deinit();
        }
        genericCssRuleSet.selectorToDeclarationMap.deinit();
        genericCssRuleSet.allocator.destroy(genericCssRuleSet);
    }

    /// Get the declarations that apply to the given node.
    /// For example, if the node is a body then all declarations should be returned within a block
    /// that looks like "body { prop1: value1; prop2: value2; }" because they apply to a body element
    fn getDeclarations(this: *RuleSet, node: *Node, allocator: *Allocator) anyerror!ArrayList(Declaration) {
        const genericCssRuleSet: *GenericCssRuleSet = @fieldParentPtr(GenericCssRuleSet, "ruleSet", this);

        var declarations: ArrayList(Declaration) = ArrayList(Declaration).init(allocator);

        var descendentOfBody: bool = false;
        var currentNode: ?*Node = node;
        while (currentNode != null) : (currentNode = currentNode.?.parentNode) {
            if (std.mem.eql(u8, "BODY", currentNode.?.nodeName)) {
                descendentOfBody = true;
                break;
            }
        }

        // TODO: This needs to be generalized to work for more than just body
        if (descendentOfBody) {
            const bodyDeclarations = genericCssRuleSet.selectorToDeclarationMap.get("BODY");
            if (bodyDeclarations != null) {
                for (bodyDeclarations.?.items) |declaration| {
                    try declarations.append(declaration);
                }
            }
        }

        return declarations;
    }
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
            ruleSet.deinit();
            composite.allocator.destroy(ruleSet);
        }
        composite.ruleSets.deinit();
        composite.allocator.destroy(composite);
    }

    pub fn addRuleSet(this: *CompositeCssRuleSet, ruleSet: *RuleSet) !void {
        try this.ruleSets.append(ruleSet);
    }

    fn getDeclarations(this: *RuleSet, node: *Node, allocator: *Allocator) anyerror!ArrayList(Declaration) {
        var composite: *CompositeCssRuleSet = @fieldParentPtr(CompositeCssRuleSet, "ruleSet", this);
        var declarations: ArrayList(Declaration) = ArrayList(Declaration).init(allocator);

        for (composite.ruleSets.items) |ruleSet, i| {
            var ruleSetDeclarations: ArrayList(Declaration) = try ruleSet.getDeclarations(node, allocator);
            for (ruleSetDeclarations.items) |declaration| {
                try declarations.append(declaration);
            }
            ruleSetDeclarations.deinit();
        }
        return declarations;
    }

    allocator: *Allocator,
    ruleSets: ArrayList(*RuleSet),
    ruleSet: RuleSet = RuleSet{
        .getDeclarationsFn = CompositeCssRuleSet.getDeclarations,
        .deinitFn = CompositeCssRuleSet.deinit,
    },
};

test "CSS length" {
    const declaration: Declaration = Declaration{
        .property = "margin-top",
        .value = CssValue{
            .length = CssLengthType{
                .value = .{ .int = 8 },
                .unit = CssLengthUnit.px,
            },
        },
    };

    var isIt8Pixels: bool = false;
    switch (declaration.value) {
        CssValueType.length => |length| {
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
    const declaration: Declaration = Declaration{
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
    switch (declaration.value) {
        CssValueType.color => |color| {
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
    const declaration: Declaration = Declaration{
        .property = "text-align",
        .value = CssValue{
            .textAlign = CssTextAlign.center,
        },
    };

    try expectEqual(true, switch (declaration.value) {
        CssValueType.textAlign => |textAlign| if (textAlign == CssTextAlign.center) true else false,
        else => false,
    });
}
