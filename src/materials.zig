const std = @import("std");
const types = @import("types.zig");

const GPUSphere = types.GPUSphere;

// ============================================================================
// MATERIAL PRESETS - Common materials for quick use
// ============================================================================

pub const MaterialPreset = struct {
    name: []const u8,
    albedo: [3]f32,
    fuzz: f32,
    ior: f32,
    emissive: f32,
    mat_type: i32,
};

// Material Categories
pub const metals = struct {
    pub const gold = MaterialPreset{
        .name = "Gold",
        .albedo = .{ 1.0, 0.843, 0.0 },
        .fuzz = 0.0,
        .ior = 0,
        .emissive = 0,
        .mat_type = 1,
    };
    pub const silver = MaterialPreset{
        .name = "Silver",
        .albedo = .{ 0.95, 0.95, 0.95 },
        .fuzz = 0.0,
        .ior = 0,
        .emissive = 0,
        .mat_type = 1,
    };
    pub const copper = MaterialPreset{
        .name = "Copper",
        .albedo = .{ 0.95, 0.64, 0.54 },
        .fuzz = 0.1,
        .ior = 0,
        .emissive = 0,
        .mat_type = 1,
    };
    pub const bronze = MaterialPreset{
        .name = "Bronze",
        .albedo = .{ 0.8, 0.5, 0.2 },
        .fuzz = 0.15,
        .ior = 0,
        .emissive = 0,
        .mat_type = 1,
    };
    pub const chrome = MaterialPreset{
        .name = "Chrome",
        .albedo = .{ 0.98, 0.98, 0.98 },
        .fuzz = 0.0,
        .ior = 0,
        .emissive = 0,
        .mat_type = 1,
    };
    pub const brushed_steel = MaterialPreset{
        .name = "Brushed Steel",
        .albedo = .{ 0.7, 0.7, 0.75 },
        .fuzz = 0.3,
        .ior = 0,
        .emissive = 0,
        .mat_type = 1,
    };
    pub const aluminum = MaterialPreset{
        .name = "Aluminum",
        .albedo = .{ 0.91, 0.92, 0.92 },
        .fuzz = 0.05,
        .ior = 0,
        .emissive = 0,
        .mat_type = 1,
    };
};

pub const glass = struct {
    pub const clear = MaterialPreset{
        .name = "Clear Glass",
        .albedo = .{ 1.0, 1.0, 1.0 },
        .fuzz = 0,
        .ior = 1.5,
        .emissive = 0,
        .mat_type = 2,
    };
    pub const tinted_blue = MaterialPreset{
        .name = "Blue Tinted",
        .albedo = .{ 0.8, 0.9, 1.0 },
        .fuzz = 0,
        .ior = 1.5,
        .emissive = 0,
        .mat_type = 2,
    };
    pub const amber = MaterialPreset{
        .name = "Amber Glass",
        .albedo = .{ 1.0, 0.85, 0.5 },
        .fuzz = 0,
        .ior = 1.55,
        .emissive = 0,
        .mat_type = 2,
    };
    pub const diamond = MaterialPreset{
        .name = "Diamond",
        .albedo = .{ 1.0, 1.0, 1.0 },
        .fuzz = 0,
        .ior = 2.42,
        .emissive = 0,
        .mat_type = 2,
    };
    pub const water = MaterialPreset{
        .name = "Water",
        .albedo = .{ 0.95, 0.98, 1.0 },
        .fuzz = 0,
        .ior = 1.33,
        .emissive = 0,
        .mat_type = 2,
    };
    pub const frosted = MaterialPreset{
        .name = "Frosted Glass",
        .albedo = .{ 0.95, 0.95, 0.95 },
        .fuzz = 0.1,
        .ior = 1.5,
        .emissive = 0,
        .mat_type = 2,
    };
};

pub const diffuse = struct {
    pub const red = MaterialPreset{
        .name = "Red Matte",
        .albedo = .{ 0.85, 0.15, 0.15 },
        .fuzz = 0,
        .ior = 0,
        .emissive = 0,
        .mat_type = 0,
    };
    pub const green = MaterialPreset{
        .name = "Green Matte",
        .albedo = .{ 0.15, 0.85, 0.15 },
        .fuzz = 0,
        .ior = 0,
        .emissive = 0,
        .mat_type = 0,
    };
    pub const blue = MaterialPreset{
        .name = "Blue Matte",
        .albedo = .{ 0.15, 0.15, 0.85 },
        .fuzz = 0,
        .ior = 0,
        .emissive = 0,
        .mat_type = 0,
    };
    pub const white = MaterialPreset{
        .name = "White Matte",
        .albedo = .{ 0.9, 0.9, 0.9 },
        .fuzz = 0,
        .ior = 0,
        .emissive = 0,
        .mat_type = 0,
    };
    pub const black = MaterialPreset{
        .name = "Black Matte",
        .albedo = .{ 0.05, 0.05, 0.05 },
        .fuzz = 0,
        .ior = 0,
        .emissive = 0,
        .mat_type = 0,
    };
    pub const orange = MaterialPreset{
        .name = "Orange Matte",
        .albedo = .{ 1.0, 0.5, 0.0 },
        .fuzz = 0,
        .ior = 0,
        .emissive = 0,
        .mat_type = 0,
    };
    pub const purple = MaterialPreset{
        .name = "Purple Matte",
        .albedo = .{ 0.6, 0.2, 0.8 },
        .fuzz = 0,
        .ior = 0,
        .emissive = 0,
        .mat_type = 0,
    };
    pub const clay = MaterialPreset{
        .name = "Clay",
        .albedo = .{ 0.76, 0.6, 0.42 },
        .fuzz = 0,
        .ior = 0,
        .emissive = 0,
        .mat_type = 0,
    };
};

pub const emissive = struct {
    pub const warm_light = MaterialPreset{
        .name = "Warm Light",
        .albedo = .{ 1.0, 0.9, 0.7 },
        .fuzz = 0,
        .ior = 0,
        .emissive = 5.0,
        .mat_type = 3,
    };
    pub const cool_light = MaterialPreset{
        .name = "Cool Light",
        .albedo = .{ 0.8, 0.9, 1.0 },
        .fuzz = 0,
        .ior = 0,
        .emissive = 5.0,
        .mat_type = 3,
    };
    pub const sun = MaterialPreset{
        .name = "Sun",
        .albedo = .{ 1.0, 0.95, 0.8 },
        .fuzz = 0,
        .ior = 0,
        .emissive = 10.0,
        .mat_type = 3,
    };
    pub const neon_red = MaterialPreset{
        .name = "Neon Red",
        .albedo = .{ 1.0, 0.1, 0.2 },
        .fuzz = 0,
        .ior = 0,
        .emissive = 8.0,
        .mat_type = 3,
    };
    pub const neon_blue = MaterialPreset{
        .name = "Neon Blue",
        .albedo = .{ 0.2, 0.4, 1.0 },
        .fuzz = 0,
        .ior = 0,
        .emissive = 8.0,
        .mat_type = 3,
    };
    pub const neon_green = MaterialPreset{
        .name = "Neon Green",
        .albedo = .{ 0.2, 1.0, 0.4 },
        .fuzz = 0,
        .ior = 0,
        .emissive = 8.0,
        .mat_type = 3,
    };
    pub const neon_pink = MaterialPreset{
        .name = "Neon Pink",
        .albedo = .{ 1.0, 0.2, 0.8 },
        .fuzz = 0,
        .ior = 0,
        .emissive = 8.0,
        .mat_type = 3,
    };
};

pub const sss = struct {
    pub const skin = MaterialPreset{
        .name = "Skin",
        .albedo = .{ 0.9, 0.7, 0.6 },
        .fuzz = 0.1,
        .ior = 0,
        .emissive = 0,
        .mat_type = 4,
    };
    pub const jade = MaterialPreset{
        .name = "Jade",
        .albedo = .{ 0.3, 0.8, 0.4 },
        .fuzz = 0.05,
        .ior = 0,
        .emissive = 0,
        .mat_type = 4,
    };
    pub const marble = MaterialPreset{
        .name = "Marble",
        .albedo = .{ 0.95, 0.95, 0.9 },
        .fuzz = 0.02,
        .ior = 0,
        .emissive = 0,
        .mat_type = 4,
    };
    pub const wax = MaterialPreset{
        .name = "Wax",
        .albedo = .{ 0.9, 0.85, 0.7 },
        .fuzz = 0.15,
        .ior = 0,
        .emissive = 0,
        .mat_type = 4,
    };
    pub const milk = MaterialPreset{
        .name = "Milk",
        .albedo = .{ 0.98, 0.98, 0.95 },
        .fuzz = 0.1,
        .ior = 0,
        .emissive = 0,
        .mat_type = 4,
    };
};

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

pub fn applyPreset(sphere: *GPUSphere, preset: MaterialPreset) void {
    sphere.albedo = preset.albedo;
    sphere.fuzz = preset.fuzz;
    sphere.ior = preset.ior;
    sphere.emissive = preset.emissive;
    sphere.mat_type = preset.mat_type;
}

pub fn createSphereFromPreset(pos: [3]f32, radius: f32, preset: MaterialPreset) GPUSphere {
    return .{
        .center = pos,
        .radius = radius,
        .albedo = preset.albedo,
        .fuzz = preset.fuzz,
        .ior = preset.ior,
        .emissive = preset.emissive,
        .mat_type = preset.mat_type,
        .pad = 0,
    };
}

// Get all presets as a flat list (for UI)
pub const all_presets = [_]MaterialPreset{
    // Metals
    metals.gold,
    metals.silver,
    metals.copper,
    metals.bronze,
    metals.chrome,
    metals.brushed_steel,
    metals.aluminum,
    // Glass
    glass.clear,
    glass.tinted_blue,
    glass.amber,
    glass.diamond,
    glass.water,
    glass.frosted,
    // Diffuse
    diffuse.red,
    diffuse.green,
    diffuse.blue,
    diffuse.white,
    diffuse.black,
    diffuse.orange,
    diffuse.purple,
    diffuse.clay,
    // Emissive
    emissive.warm_light,
    emissive.cool_light,
    emissive.sun,
    emissive.neon_red,
    emissive.neon_blue,
    emissive.neon_green,
    emissive.neon_pink,
    // SSS
    sss.skin,
    sss.jade,
    sss.marble,
    sss.wax,
    sss.milk,
};

pub fn getPresetByName(name: []const u8) ?MaterialPreset {
    for (all_presets) |preset| {
        if (std.mem.eql(u8, preset.name, name)) {
            return preset;
        }
    }
    return null;
}

pub fn getPresetIndex(name: []const u8) ?usize {
    for (all_presets, 0..) |preset, i| {
        if (std.mem.eql(u8, preset.name, name)) {
            return i;
        }
    }
    return null;
}
