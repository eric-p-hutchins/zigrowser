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
    aqua,
    black,
    blue,
    fuchsia,
    gray,
    green,
    lime,
    maroon,
    navy,
    olive,
    orange,
    purple,
    red,
    silver,
    teal,
    white,
    yellow,

    pub fn toRgbColor(this: CssColorKeyword) CssRgbColor {
        return switch (this) {
            .aqua => CssRgbColor{ .r = 0, .g = 255, .b = 255 },
            .black => CssRgbColor{ .r = 0, .g = 0, .b = 0 },
            .blue => CssRgbColor{ .r = 0, .g = 0, .b = 255 },
            .fuchsia => CssRgbColor{ .r = 255, .g = 0, .b = 255 },
            .gray => CssRgbColor{ .r = 128, .g = 128, .b = 128 },
            .green => CssRgbColor{ .r = 0, .g = 128, .b = 0 },
            .lime => CssRgbColor{ .r = 0, .g = 255, .b = 0 },
            .maroon => CssRgbColor{ .r = 128, .g = 0, .b = 0 },
            .navy => CssRgbColor{ .r = 0, .g = 128, .b = 0 },
            .olive => CssRgbColor{ .r = 128, .g = 128, .b = 0 },
            .orange => CssRgbColor{ .r = 255, .g = 165, .b = 0 },
            .purple => CssRgbColor{ .r = 128, .g = 0, .b = 128 },
            .red => CssRgbColor{ .r = 255, .g = 0, .b = 0 },
            .silver => CssRgbColor{ .r = 192, .g = 192, .b = 192 },
            .teal => CssRgbColor{ .r = 0, .g = 128, .b = 128 },
            .white => CssRgbColor{ .r = 255, .g = 255, .b = 255 },
            .yellow => CssRgbColor{ .r = 255, .g = 255, .b = 0 },
        };
    }
};

pub const CssRgbColor = struct {
    r: u8,
    g: u8,
    b: u8,
};

pub const CssTextAlign = enum {
    left,
    right,
    center,
};

pub const CssColor = union(enum) {
    keyword: CssColorKeyword,
    rgb: CssRgbColor,

    pub fn toRgbColor(this: CssColor) CssRgbColor {
        switch (this) {
            .keyword => return this.keyword.toRgbColor(),
            .rgb => return this.rgb,
        }
    }
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

    pub fn deinit(allocator: *Allocator, declaration: *Declaration) void {
        allocator.free(declaration.property);
        allocator.destroy(declaration);
    }

    pub fn dupe(allocator: *Allocator, declaration: *const Declaration) !*Declaration {
        var dupDec = try allocator.create(Declaration);
        dupDec.* = Declaration{
            .property = try std.mem.dupe(allocator, u8, declaration.property),
            .value = declaration.value,
        };
        return dupDec;
    }
};

pub const CssParser = struct {
    fn parseColor(value: []const u8) ?CssValue {
        if (value[0] == '#') {
            var hex1 = value[1];
            var hex2 = value[2];
            var hex3 = value[3];
            var hex4 = value[4];
            var hex5 = value[5];
            var hex6 = value[6];
            var d1: u8 = 0;
            var d2: u8 = 0;
            var d3: u8 = 0;
            if (hex1 >= 'a' and hex1 <= 'f') {
                d1 = 16 * (10 + (hex1 - 'a'));
            } else if (hex1 >= 'A' and hex1 <= 'F') {
                d1 = 16 * (10 + (hex1 - 'A'));
            } else if (hex1 >= '0' and hex1 <= '9') {
                d1 = 16 * (hex1 - '0');
            }
            if (hex2 >= 'a' and hex2 <= 'f') {
                d1 += 10 + (hex2 - 'a');
            } else if (hex2 >= 'A' and hex2 <= 'F') {
                d1 += 10 + (hex2 - 'A');
            } else if (hex2 >= '0' and hex2 <= '9') {
                d1 += hex2 - '0';
            }
            if (hex3 >= 'a' and hex3 <= 'f') {
                d2 = 16 * (10 + (hex3 - 'a'));
            } else if (hex3 >= 'A' and hex3 <= 'F') {
                d2 = 16 * (10 + (hex3 - 'A'));
            } else if (hex3 >= '0' and hex3 <= '9') {
                d2 = 16 * (hex3 - '0');
            }
            if (hex4 >= 'a' and hex4 <= 'f') {
                d2 += 10 + (hex4 - 'a');
            } else if (hex4 >= 'A' and hex4 <= 'F') {
                d2 += 10 + (hex4 - 'A');
            } else if (hex4 >= '0' and hex4 <= '9') {
                d2 += hex4 - '0';
            }
            if (hex5 >= 'a' and hex5 <= 'f') {
                d3 = 16 * (10 + (hex5 - 'a'));
            } else if (hex5 >= 'A' and hex5 <= 'F') {
                d3 = 16 * (10 + (hex5 - 'A'));
            } else if (hex5 >= '0' and hex5 <= '9') {
                d3 = 16 * (hex5 - '0');
            }
            if (hex6 >= 'a' and hex6 <= 'f') {
                d3 += 10 + (hex6 - 'a');
            } else if (hex6 >= 'A' and hex6 <= 'F') {
                d3 += 10 + (hex6 - 'A');
            } else if (hex6 >= '0' and hex6 <= '9') {
                d3 += hex6 - '0';
            }

            return CssValue{
                .color = CssColor{
                    .rgb = CssRgbColor{ .r = d1, .g = d2, .b = d3 },
                },
            };
        } else {
            for (std.enums.values(CssColorKeyword)) |keyword| {
                if (std.mem.eql(u8, @tagName(keyword), value)) {
                    return CssValue{ .color = CssColor{ .keyword = keyword } };
                }
            }
        }
        return null;
    }

    pub fn parseLength(value: []const u8) !?CssValue {
        if (value.len > 1 and value[value.len - 1] == '%') {
            var int_val: ?i64 = null;
            var float_val: ?f64 = null;
            int_val = std.fmt.parseInt(i64, value[0 .. value.len - 1], 10) catch null;
            if (int_val == null) {
                float_val = try std.fmt.parseFloat(f64, value[0 .. value.len - 1]);
            }
            if (int_val != null) {
                return CssValue{ .length = CssLengthType{ .value = CssNumber{ .int = int_val.? }, .unit = .percent } };
            } else if (float_val != null) {
                return CssValue{ .length = CssLengthType{ .value = CssNumber{ .float = float_val.? }, .unit = .percent } };
            }
        } else if (value.len > 2 and value[value.len - 2] == 'p' and value[value.len - 1] == 'x') {
            var int_val: ?i64 = null;
            var float_val: ?f64 = null;
            int_val = std.fmt.parseInt(i64, value[0 .. value.len - 2], 10) catch null;
            if (int_val == null) {
                float_val = try std.fmt.parseFloat(f64, value[0 .. value.len - 2]);
            }
            if (int_val != null) {
                return CssValue{ .length = CssLengthType{ .value = CssNumber{ .int = int_val.? }, .unit = .px } };
            } else if (float_val != null) {
                return CssValue{ .length = CssLengthType{ .value = CssNumber{ .float = float_val.? }, .unit = .px } };
            }
        }
        return null;
    }

    fn isLengthType(property: []const u8) bool {
        if (std.mem.eql(u8, "width", property)) return true;
        if (std.mem.eql(u8, "margin", property)) return true;
        if (std.mem.eql(u8, "margin-top", property)) return true;
        if (std.mem.eql(u8, "margin-left", property)) return true;
        if (std.mem.eql(u8, "margin-bottom", property)) return true;
        if (std.mem.eql(u8, "margin-right", property)) return true;
        if (std.mem.eql(u8, "padding", property)) return true;
        if (std.mem.eql(u8, "padding-top", property)) return true;
        if (std.mem.eql(u8, "padding-left", property)) return true;
        if (std.mem.eql(u8, "padding-bottom", property)) return true;
        if (std.mem.eql(u8, "padding-right", property)) return true;
        return false;
    }

    pub fn parse(allocator: *Allocator, text: []const u8, noBlock: bool) !*RuleSet {
        var genericRuleSet = try GenericCssRuleSet.init(allocator);

        var inAtRule: bool = false;
        var inBlock: bool = noBlock;
        var inProperty: bool = noBlock;
        var inValue: bool = false;

        var selector = ArrayList(u8).init(allocator);
        var property = ArrayList(u8).init(allocator);
        var value = ArrayList(u8).init(allocator);

        for (text) |byte, i| {
            if (inAtRule) {
                // This is not actually good enough but works for my test case
                if (byte == '}') {
                    inAtRule = false;
                }
            } else if (!inBlock) { // !inAtRule
                if (byte == '@') {
                    inAtRule = true;
                } else if (byte != '{' and byte != ' ' and byte != '\n') {
                    try selector.append(byte);
                } else if (byte == '{') { // byte == '{'
                    inBlock = true;
                    inProperty = true;
                }
            } else { // !inAtRule and inBlock
                if (inProperty) {
                    if (byte == ':') {
                        inProperty = false;
                        inValue = true;
                    } else if (byte != ' ' and byte != '\n') {
                        try property.append(byte);
                    }
                } else {
                    if (byte == ';') {
                        inValue = false;

                        var upperSelector = try std.ascii.allocUpperString(allocator, selector.items);
                        errdefer allocator.free(upperSelector);

                        if (isLengthType(property.items)) {
                            var cssValue = try parseLength(value.items);
                            if (cssValue) |cssVal| {
                                var declaration: Declaration = Declaration{
                                    .property = property.items,
                                    .value = cssVal,
                                };

                                try genericRuleSet.addDeclaration(upperSelector, &declaration);
                            }
                        } else if (std.mem.eql(u8, "background-color", property.items) or std.mem.eql(u8, "color", property.items)) {
                            var cssValue = parseColor(value.items);
                            if (cssValue) |cssVal| {
                                var declaration: Declaration = Declaration{
                                    .property = property.items,
                                    .value = cssVal,
                                };

                                try genericRuleSet.addDeclaration(upperSelector, &declaration);
                            }
                        }
                        allocator.free(upperSelector);
                        property.clearRetainingCapacity();
                        value.clearRetainingCapacity();
                        inProperty = true;
                    } else if (byte != ' ' and byte != '\n') {
                        try value.append(byte);
                    }
                }
            }
        }

        if (inValue) {
            inValue = false;

            var upperSelector = try std.ascii.allocUpperString(allocator, selector.items);
            errdefer allocator.free(upperSelector);

            if (std.mem.eql(u8, "width", property.items) or std.mem.eql(u8, "margin", property.items)) {
                var cssValue = try parseLength(value.items);
                if (cssValue) |cssVal| {
                    var declaration: Declaration = Declaration{
                        .property = property.items,
                        .value = cssVal,
                    };

                    try genericRuleSet.addDeclaration(upperSelector, &declaration);
                }
            } else if (std.mem.eql(u8, "background-color", property.items) or std.mem.eql(u8, "color", property.items)) {
                var cssValue = parseColor(value.items);
                if (cssValue) |cssVal| {
                    var declaration: Declaration = Declaration{
                        .property = property.items,
                        .value = cssVal,
                    };

                    try genericRuleSet.addDeclaration(upperSelector, &declaration);
                }
            }
            allocator.free(upperSelector);
            property.clearRetainingCapacity();
            value.clearRetainingCapacity();
            inProperty = true;
        }

        selector.deinit();
        property.deinit();
        value.deinit();

        return &genericRuleSet.ruleSet;
    }
};

test "CSS parser" {
    var ruleSet = try CssParser.parse(std.testing.allocator, "body{background-color: #131315;color:white}");
    defer ruleSet.deinit();
}

const SelectorToDeclarationMap = std.StringHashMap(ArrayList(*Declaration));

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
    allocator: *Allocator,
    ruleSet: RuleSet = RuleSet{
        .getDeclarationsFn = getDeclarations,
        .deinitFn = deinit,
    },

    fn deinit(this: *RuleSet) void {
        var userAgentCssRuleSet = @fieldParentPtr(UserAgentCssRuleSet, "ruleSet", this);
        userAgentCssRuleSet.allocator.destroy(this);
    }

    pub fn init(allocator: *Allocator) !*UserAgentCssRuleSet {
        var userAgentCssRuleSet = try allocator.create(UserAgentCssRuleSet);
        userAgentCssRuleSet.* = UserAgentCssRuleSet{
            .allocator = allocator,
        };
        return userAgentCssRuleSet;
    }

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
};

pub const GenericCssRuleSet = struct {
    allocator: *Allocator,
    keys: ArrayList([]const u8),
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
            .keys = ArrayList([]const u8).init(allocator),
        };

        return genericCssRuleSet;
    }

    pub fn addDeclaration(this: *GenericCssRuleSet, selector: []const u8, declaration: *const Declaration) !void {
        var key = try this.allocator.dupe(u8, selector);
        try this.keys.append(key);
        var optionalDeclarations = this.selectorToDeclarationMap.get(key);
        if (optionalDeclarations == null) {
            try this.selectorToDeclarationMap.put(key, ArrayList(*Declaration).init(this.allocator));
        }
        var declarations = this.selectorToDeclarationMap.get(key).?;
        try declarations.append(try Declaration.dupe(this.allocator, declaration));
        try this.selectorToDeclarationMap.put(key, declarations);
    }

    fn deinit(this: *RuleSet) void {
        const genericCssRuleSet: *GenericCssRuleSet = @fieldParentPtr(GenericCssRuleSet, "ruleSet", this);

        var iterator = genericCssRuleSet.selectorToDeclarationMap.valueIterator();
        var list: ?*ArrayList(*Declaration) = iterator.next();
        while (list != null) : (list = iterator.next()) {
            for (list.?.items) |item| {
                Declaration.deinit(genericCssRuleSet.allocator, item);
            }
            list.?.deinit();
        }

        for (genericCssRuleSet.keys.items) |item| {
            genericCssRuleSet.allocator.free(item);
        }
        genericCssRuleSet.keys.deinit();

        genericCssRuleSet.selectorToDeclarationMap.deinit();
        genericCssRuleSet.allocator.destroy(genericCssRuleSet);
    }

    /// Get the declarations that apply to the given node.
    /// For example, if the node is a body then all declarations should be returned within a block
    /// that looks like "body { prop1: value1; prop2: value2; }" because they apply to a body element
    fn getDeclarations(this: *RuleSet, node: *Node, allocator: *Allocator) anyerror!ArrayList(Declaration) {
        const genericCssRuleSet: *GenericCssRuleSet = @fieldParentPtr(GenericCssRuleSet, "ruleSet", this);

        var declarations: ArrayList(Declaration) = ArrayList(Declaration).init(allocator);

        if (std.mem.eql(u8, "BODY", node.nodeName)) {
            const bodyDeclarations = genericCssRuleSet.selectorToDeclarationMap.get("BODY");
            if (bodyDeclarations != null) {
                for (bodyDeclarations.?.items) |declaration| {
                    try declarations.append(declaration.*);
                }
            }
        }

        // TODO: This needs to be generalized to inherit certain properties from any parent node, not just body
        var descendentOfBody: bool = false;
        var currentNode: ?*Node = node;
        while (currentNode != null) : (currentNode = currentNode.?.parentNode) {
            if (std.mem.eql(u8, "BODY", currentNode.?.nodeName)) {
                descendentOfBody = true;
                break;
            }
        }
        if (descendentOfBody) {
            const bodyDeclarations = genericCssRuleSet.selectorToDeclarationMap.get("BODY");
            if (bodyDeclarations != null) {
                for (bodyDeclarations.?.items) |declaration| {
                    // TODO: Add infrastructure for specifying which properties are inherited or not
                    //
                    // background-color is not while color is, etc.
                    if (std.mem.eql(u8, "color", declaration.property)) {
                        try declarations.append(declaration.*);
                    }
                }
            }
        }

        const noBlockDeclarations = genericCssRuleSet.selectorToDeclarationMap.get("");
        if (noBlockDeclarations != null) {
            for (noBlockDeclarations.?.items) |declaration| {
                try declarations.append(declaration.*);
            }
        }

        return declarations;
    }
};

pub const CompositeCssRuleSet = struct {
    allocator: *Allocator,
    ruleSets: ArrayList(*RuleSet),
    ruleSet: RuleSet = RuleSet{
        .getDeclarationsFn = CompositeCssRuleSet.getDeclarations,
        .deinitFn = CompositeCssRuleSet.deinit,
    },

    pub fn init(allocator: *Allocator) !*CompositeCssRuleSet {
        var ruleSet = try allocator.create(CompositeCssRuleSet);
        ruleSet.* = CompositeCssRuleSet{
            .allocator = allocator,
            .ruleSets = ArrayList(*RuleSet).init(allocator),
        };
        return ruleSet;
    }

    fn deinit(this: *RuleSet) void {
        var composite: *CompositeCssRuleSet = @fieldParentPtr(CompositeCssRuleSet, "ruleSet", this);
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
                .rgb = CssRgbColor{
                    .r = 255,
                    .g = 255,
                    .b = 255,
                },
            },
        },
    };

    var isItWhite: bool = false;
    switch (declaration.value) {
        CssValueType.color => |color| {
            switch (color) {
                CssColor.rgb => |rgb| {
                    if (rgb.r == 255 and rgb.g == 255 and rgb.b == 255) {
                        isItWhite = true;
                    }
                },
                CssColor.keyword => |keyword| {},
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
