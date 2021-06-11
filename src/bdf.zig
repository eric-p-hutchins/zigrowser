const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const BoundingBox = struct {
    width: u8,
    height: u8,
    xOff: i8,
    yOff: i8,
};

pub const BDFChar = struct {
    boundingBox: ?BoundingBox,
    dWidth: u8,
    dHeight: u8,
    codePoint: u32,
    lines: [][]u8,
};

const Error = error{CodePointNotFound};

pub const BDFFont = struct {
    const This = @This();

    allocator: *Allocator,
    boundingBox: BoundingBox,
    chars: ArrayList(BDFChar),

    pub fn getChar(this: This, codePoint: u8) !BDFChar {
        for (this.chars.items) |char| {
            if (char.codePoint == codePoint) {
                return char;
            }
        }
        return error.CodePointNotFound;
    }

    pub fn parse(allocator: *Allocator, file: [:0]const u8) !BDFFont {
        var lineStart: usize = 0;
        var codePoint: u32 = 0;
        var charName: []const u8 = "";
        var inBitmap: bool = false;
        var nChars: u32 = 0;
        var charsList = ArrayList(BDFChar).init(allocator);
        var lines: ArrayList([]u8) = undefined;
        var nCharsAdded: u32 = 0;
        var dWidth: u8 = 0;
        var dHeight: u8 = 0;
        var fontBoundingBox: BoundingBox = BoundingBox{ .width = 0, .height = 0, .xOff = 0, .yOff = 0 };
        var boundingBox: ?BoundingBox = null;
        for (file) |byte, i| {
            if (byte == '\n') {
                var line: []const u8 = file[lineStart..i];
                if (line.len >= 9 and std.mem.eql(u8, line[0..9], "STARTCHAR"[0..9])) {
                    charName = line[10..];
                    lines = ArrayList([]u8).init(allocator);
                } else if (line.len >= 6 and std.mem.eql(u8, line[0..6], "CHARS "[0..6])) {
                    for (line[6..]) |decByte| {
                        nChars *= 10;
                        nChars += decByte - '0';
                    }
                } else if (line.len >= 7 and std.mem.eql(u8, line[0..7], "DWIDTH "[0..7])) {
                    var dHeightStart: u32 = 7;
                    for (line[7..]) |decByte, j| {
                        if (decByte == ' ') {
                            dHeightStart = 7 + @intCast(u32, j) + 1;
                            break;
                        }
                        dWidth *= 10;
                        dWidth += decByte - '0';
                    }
                    for (line[dHeightStart..]) |decByte| {
                        if (decByte == ' ') {
                            break;
                        }
                        dHeight *= 10;
                        dHeight += decByte - '0';
                    }
                } else if (line.len >= 16 and std.mem.eql(u8, line[0..16], "FONTBOUNDINGBOX "[0..16])) {
                    var start: u32 = 16;
                    var neg: bool = false;

                    for (line[start..]) |decByte, j| {
                        if (decByte == ' ') {
                            start = start + @intCast(u32, j) + 1;
                            break;
                        } else {
                            fontBoundingBox.width *= 10;
                            fontBoundingBox.width += decByte - '0';
                        }
                    }

                    for (line[start..]) |decByte, j| {
                        if (decByte == ' ') {
                            start = start + @intCast(u32, j) + 1;
                            break;
                        } else {
                            fontBoundingBox.height *= 10;
                            fontBoundingBox.height += decByte - '0';
                        }
                    }

                    for (line[start..]) |decByte, j| {
                        if (decByte == ' ') {
                            start = start + @intCast(u32, j) + 1;
                            break;
                        } else if (decByte == '-') {
                            neg = true;
                        } else {
                            fontBoundingBox.xOff *= 10;
                            fontBoundingBox.xOff += @intCast(i8, decByte - '0');
                        }
                    }
                    if (neg) {
                        fontBoundingBox.xOff *= -1;
                    }
                    neg = false;

                    for (line[start..]) |decByte, j| {
                        if (decByte == ' ') {
                            break;
                        } else if (decByte == '-') {
                            neg = true;
                        } else {
                            fontBoundingBox.yOff *= 10;
                            fontBoundingBox.yOff += @intCast(i8, decByte - '0');
                        }
                    }
                    if (neg) {
                        fontBoundingBox.yOff *= -1;
                    }
                    neg = false;
                } else if (line.len >= 4 and std.mem.eql(u8, line[0..4], "BBX "[0..4])) {
                    var realBoundingBox = BoundingBox{ .width = 0, .height = 0, .xOff = 0, .yOff = 0 };
                    var start: u32 = 4;
                    var neg: bool = false;

                    for (line[start..]) |decByte, j| {
                        if (decByte == ' ') {
                            start = start + @intCast(u32, j) + 1;
                            break;
                        } else {
                            realBoundingBox.width *= 10;
                            realBoundingBox.width += decByte - '0';
                        }
                    }

                    for (line[start..]) |decByte, j| {
                        if (decByte == ' ') {
                            start = start + @intCast(u32, j) + 1;
                            break;
                        } else {
                            realBoundingBox.height *= 10;
                            realBoundingBox.height += decByte - '0';
                        }
                    }

                    for (line[start..]) |decByte, j| {
                        if (decByte == ' ') {
                            start = start + @intCast(u32, j) + 1;
                            break;
                        } else if (decByte == '-') {
                            neg = true;
                        } else {
                            realBoundingBox.xOff *= 10;
                            realBoundingBox.xOff += @intCast(i8, decByte - '0');
                        }
                    }
                    if (neg) {
                        realBoundingBox.xOff *= -1;
                    }
                    neg = false;

                    for (line[start..]) |decByte, j| {
                        if (decByte == ' ') {
                            break;
                        } else if (decByte == '-') {
                            neg = true;
                        } else {
                            realBoundingBox.yOff *= 10;
                            realBoundingBox.yOff += @intCast(i8, decByte - '0');
                        }
                    }
                    if (neg) {
                        realBoundingBox.yOff *= -1;
                    }
                    neg = false;

                    boundingBox = realBoundingBox;
                } else if (line.len >= 8 and std.mem.eql(u8, line[0..8], "ENCODING"[0..8])) {
                    for (line[9..]) |decByte| {
                        codePoint *= 10;
                        codePoint += decByte - '0';
                    }
                } else if (line.len >= 6 and std.mem.eql(u8, line[0..6], "BITMAP"[0..6])) {
                    inBitmap = true;
                } else if (line.len >= 7 and std.mem.eql(u8, line[0..7], "ENDCHAR"[0..7])) {
                    nCharsAdded += 1;
                    var realBoundingBox = boundingBox orelse BoundingBox{ .width = 0, .height = 0, .xOff = 0, .yOff = 0 };
                    charsList.append(BDFChar{
                        .boundingBox = boundingBox,
                        .lines = lines.items,
                        .codePoint = codePoint,
                        .dWidth = dWidth,
                        .dHeight = dHeight,
                    }) catch |err| {
                        std.log.info("error appending... {}", .{err});
                    };

                    inBitmap = false;
                    charName = "";
                    codePoint = 0;
                    dWidth = 0;
                    dHeight = 0;
                    boundingBox = null;
                }
                if (inBitmap and (line.len < 6 or !std.mem.eql(u8, line[0..6], "BITMAP"[0..6]))) {
                    var charLine: []u8 = try allocator.alloc(u8, line.len * 4);
                    var charLineIndex: u8 = 0;
                    for (line) |hexbyte| {
                        var bitmapByte: u4 = 0;
                        if (hexbyte >= '0' and hexbyte <= '9') {
                            bitmapByte = @intCast(u4, hexbyte - '0');
                        } else {
                            bitmapByte = @intCast(u4, (hexbyte - 'A') + 10);
                        }
                        for (charLine[charLineIndex .. charLineIndex + 4]) |*bit, k| {
                            bit.* = if ((bitmapByte >> @intCast(u2, 3 - k)) & 0b1 == 0) ' ' else '#';
                        }
                        charLineIndex += 4;
                    }
                    lines.append(charLine) catch |err| {
                        std.log.info("error appending line... {}", .{err});
                    };
                }
                lineStart = i + 1;
            }
        }
        return BDFFont{
            .allocator = allocator,
            .boundingBox = fontBoundingBox,
            .chars = charsList,
        };
    }

    pub fn deinit(self: *BDFFont) void {
        self.chars.deinit();
    }
};
