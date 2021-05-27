const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const c = @import("c.zig");

const FT_Library = c.FT_Library;
const FT_Face = c.FT_Face;

const dejaVuEmbed = @embedFile("DejaVuSans.ttf");

pub fn initFreeType(allocator: *Allocator) !*FT_Library {
    var library: ?*FT_Library = try allocator.create(FT_Library);
    _ = c.FT_Init_FreeType(library);
    return library orelse error.FreeTypeInitializationError;
}

pub fn loadFace(allocator: *Allocator, library: *FT_Library, path: [*c]const u8) !*FT_Face {
    var face: ?*FT_Face = try allocator.create(FT_Face);
    _ = c.FT_New_Face(library.*, path, 0, face);
    return face orelse error.FreeTypeInitializationError;
}

pub fn loadFaceMemory(allocator: *Allocator, library: *FT_Library, memory: [*c]const u8, length: c_long) !*FT_Face {
    var face: ?*FT_Face = try allocator.create(FT_Face);
    _ = c.FT_New_Memory_Face(library.*, memory, length, 0, face);
    return face orelse error.FreeTypeInitializationError;
}

pub const Fonts = struct {
    library: *FT_Library,
    fonts: ArrayList(*FT_Face),

    pub fn init(allocator: *Allocator) !Fonts {
        var library: *FT_Library = try initFreeType(allocator);
        // var dejavuSansFace: *FT_Face = try loadFace(library, "DejaVuSans.ttf");
        var fonts = ArrayList(*FT_Face).init(allocator);
        var dejavuSansFace: *FT_Face = try loadFaceMemory(allocator, library, dejaVuEmbed, dejaVuEmbed.len);

        var errorCode = c.FT_Set_Char_Size(dejavuSansFace.*, 0, 16 * 64, 72, 72);
        if (errorCode != 0) {
            std.log.info("error setting char size. code: {}", .{errorCode});
        }

        try fonts.append(dejavuSansFace);

        return Fonts{
            .library = library,
            .fonts = fonts,
        };
    }
};