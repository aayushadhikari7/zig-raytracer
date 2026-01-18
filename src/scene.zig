const std = @import("std");
const vec3 = @import("vec3.zig");
const types = @import("types.zig");

const Vec3 = vec3.Vec3;
const GPUSphere = types.GPUSphere;

// ============================================================================
// DEMO CANVAS MODE - Clean scene, add objects as you go
// Like Dota 2 demo mode - a sandbox to experiment!
// ============================================================================

// Scene configuration
pub const SceneConfig = struct {
    // What to include in the scene
    include_demo_spheres: bool = false,  // Demo spheres (glass, metal, diffuse)
    include_ground: bool = true,         // Ground plane
    include_lights: bool = true,         // Light sources
};

pub var config = SceneConfig{};

pub fn setupScene(allocator: std.mem.Allocator, spheres: *std.ArrayList(GPUSphere)) !void {
    // Ground plane (always useful)
    if (config.include_ground) {
        try spheres.append(allocator, .{
            .center = .{ 0, -1000, 0 },
            .radius = 1000,
            .albedo = .{ 0.5, 0.5, 0.5 },
            .fuzz = 0,
            .ior = 0,
            .emissive = 0,
            .mat_type = 0,
            .pad = 0
        });
    }

    // Lights
    if (config.include_lights) {
        // Main sun light
        try spheres.append(allocator, .{
            .center = .{ 5, 10, -5 },
            .radius = 3.0,
            .albedo = .{ 1.0, 0.95, 0.9 },
            .fuzz = 0,
            .ior = 0,
            .emissive = 8.0,
            .mat_type = 3,
            .pad = 0
        });

        // Fill light (dimmer, blue tint)
        try spheres.append(allocator, .{
            .center = .{ -8, 5, 4 },
            .radius = 2.0,
            .albedo = .{ 0.6, 0.7, 1.0 },
            .fuzz = 0,
            .ior = 0,
            .emissive = 3.0,
            .mat_type = 3,
            .pad = 0
        });
    }

    // Demo spheres (optional - disabled by default for clean canvas)
    if (config.include_demo_spheres) {
        // Center: Glass sphere
        try spheres.append(allocator, .{ .center = .{ 0, 1, 0 }, .radius = 1.0, .albedo = .{ 1, 1, 1 }, .fuzz = 0, .ior = 1.5, .emissive = 0, .mat_type = 2, .pad = 0 });

        // Left: Red diffuse
        try spheres.append(allocator, .{ .center = .{ -3, 1, 0 }, .radius = 1.0, .albedo = .{ 0.8, 0.2, 0.2 }, .fuzz = 0, .ior = 0, .emissive = 0, .mat_type = 0, .pad = 0 });

        // Right: Gold metal
        try spheres.append(allocator, .{ .center = .{ 3, 1, 0 }, .radius = 1.0, .albedo = .{ 1.0, 0.85, 0.55 }, .fuzz = 0.0, .ior = 0, .emissive = 0, .mat_type = 1, .pad = 0 });

        // Far left: Blue diffuse
        try spheres.append(allocator, .{ .center = .{ -6, 0.7, 1 }, .radius = 0.7, .albedo = .{ 0.2, 0.3, 0.8 }, .fuzz = 0, .ior = 0, .emissive = 0, .mat_type = 0, .pad = 0 });

        // Far right: Chrome mirror
        try spheres.append(allocator, .{ .center = .{ 6, 0.7, 1 }, .radius = 0.7, .albedo = .{ 0.95, 0.95, 0.95 }, .fuzz = 0.0, .ior = 0, .emissive = 0, .mat_type = 1, .pad = 0 });

        // Behind: Large green SSS
        try spheres.append(allocator, .{ .center = .{ 0, 1.2, -4 }, .radius = 1.2, .albedo = .{ 0.4, 0.8, 0.4 }, .fuzz = 0.1, .ior = 0, .emissive = 0, .mat_type = 4, .pad = 0 });
    }
}

// ============================================================================
// SPAWN SYSTEM - Add objects dynamically (in front of camera)
// ============================================================================

var spawn_offset: f32 = 0;

// Spawn position in front of camera
pub fn getSpawnPositionInFrontOfCamera(cam_pos: [3]f32, cam_yaw: f32) [3]f32 {
    const spawn_dist: f32 = 5.0; // Distance in front of camera
    const spawn_height: f32 = 0.5; // Height above ground

    // Calculate forward direction from yaw
    const forward_x = @cos(cam_yaw);
    const forward_z = @sin(cam_yaw);

    // Add small offset to prevent overlapping
    const offset_x = @sin(spawn_offset) * 0.5;
    const offset_z = @cos(spawn_offset) * 0.5;
    spawn_offset += 1.0;

    return .{
        cam_pos[0] + forward_x * spawn_dist + offset_x,
        spawn_height,
        cam_pos[2] + forward_z * spawn_dist + offset_z,
    };
}

// Legacy function for backward compatibility (spawns at origin area)
pub fn getNextSpawnPosition() [3]f32 {
    const x = @cos(spawn_offset) * 3.0;
    const z = @sin(spawn_offset) * 3.0;
    spawn_offset += 1.2;
    return .{ x, 0.5, z };
}

pub fn resetSpawnPosition() void {
    spawn_offset = 0;
}

// ============================================================================
// SPHERE CREATORS - Different materials
// ============================================================================

// Material types:
// 0 = Diffuse (matte)
// 1 = Metal (reflective)
// 2 = Glass (transparent)
// 3 = Emissive (light source)
// 4 = SSS (subsurface scattering)

pub fn createDiffuseSphere(pos: [3]f32) GPUSphere {
    var prng = std.Random.DefaultPrng.init(@intFromFloat(@abs(pos[0] * 1000 + pos[2] * 100)));
    var rng = prng.random();
    const r = vec3.randomFloatRange(&rng, 0.2, 0.9);
    const g = vec3.randomFloatRange(&rng, 0.2, 0.9);
    const b = vec3.randomFloatRange(&rng, 0.2, 0.9);
    return .{ .center = pos, .radius = 0.5, .albedo = .{ r, g, b }, .fuzz = 0, .ior = 0, .emissive = 0, .mat_type = 0, .pad = 0 };
}

pub fn createMetalSphere(pos: [3]f32) GPUSphere {
    var prng = std.Random.DefaultPrng.init(@intFromFloat(@abs(pos[0] * 1000 + pos[2] * 100)));
    var rng = prng.random();
    const r = vec3.randomFloatRange(&rng, 0.7, 1.0);
    const g = vec3.randomFloatRange(&rng, 0.6, 1.0);
    const b = vec3.randomFloatRange(&rng, 0.5, 1.0);
    const fuzz = vec3.randomFloatRange(&rng, 0.0, 0.2);
    return .{ .center = pos, .radius = 0.5, .albedo = .{ r, g, b }, .fuzz = fuzz, .ior = 0, .emissive = 0, .mat_type = 1, .pad = 0 };
}

pub fn createGlassSphere(pos: [3]f32) GPUSphere {
    return .{ .center = pos, .radius = 0.5, .albedo = .{ 1, 1, 1 }, .fuzz = 0, .ior = 1.5, .emissive = 0, .mat_type = 2, .pad = 0 };
}

pub fn createLightSphere(pos: [3]f32) GPUSphere {
    var prng = std.Random.DefaultPrng.init(@intFromFloat(@abs(pos[0] * 1000 + pos[2] * 100)));
    var rng = prng.random();
    const r = vec3.randomFloatRange(&rng, 0.8, 1.0);
    const g = vec3.randomFloatRange(&rng, 0.7, 1.0);
    const b = vec3.randomFloatRange(&rng, 0.6, 1.0);
    return .{ .center = .{ pos[0], pos[1] + 2.0, pos[2] }, .radius = 0.3, .albedo = .{ r, g, b }, .fuzz = 0, .ior = 0, .emissive = 5.0, .mat_type = 3, .pad = 0 };
}

pub fn createSSSSphere(pos: [3]f32) GPUSphere {
    var prng = std.Random.DefaultPrng.init(@intFromFloat(@abs(pos[0] * 1000 + pos[2] * 100)));
    var rng = prng.random();
    const r = vec3.randomFloatRange(&rng, 0.3, 0.9);
    const g = vec3.randomFloatRange(&rng, 0.3, 0.9);
    const b = vec3.randomFloatRange(&rng, 0.3, 0.9);
    return .{ .center = pos, .radius = 0.5, .albedo = .{ r, g, b }, .fuzz = 0.1, .ior = 0, .emissive = 0, .mat_type = 4, .pad = 0 };
}

// Custom sphere with full control
pub fn createCustomSphere(
    pos: [3]f32,
    radius: f32,
    albedo: [3]f32,
    mat_type: i32,
    fuzz: f32,
    ior: f32,
    emissive: f32,
) GPUSphere {
    return .{
        .center = pos,
        .radius = radius,
        .albedo = albedo,
        .fuzz = fuzz,
        .ior = ior,
        .emissive = emissive,
        .mat_type = mat_type,
        .pad = 0,
    };
}

// Helper functions are now in vec3.zig

// ============================================================================
// SCENE PRESETS - Quick scene setups
// ============================================================================

pub fn enableDemoScene() void {
    config.include_demo_spheres = true;
}

pub fn enableCleanCanvas() void {
    config.include_demo_spheres = false;
}
