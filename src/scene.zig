const std = @import("std");
const vec3 = @import("vec3.zig");
const types = @import("types.zig");

const Vec3 = vec3.Vec3;
const GPUSphere = types.GPUSphere;

// ============================================================================
// SCENE SETUP - Defines the spheres in the scene
// ============================================================================

pub fn setupScene(allocator: std.mem.Allocator, spheres: *std.ArrayList(GPUSphere)) !void {
    // Ground - subtle checker-like appearance through albedo
    try spheres.append(allocator, .{ .center = .{ 0, -1000, 0 }, .radius = 1000, .albedo = .{ 0.4, 0.4, 0.45 }, .fuzz = 0, .ior = 0, .emissive = 0, .mat_type = 0, .pad = 0 });

    // === HERO SPHERES - The Stars of the Show ===

    // Center: Perfect crystal glass sphere
    try spheres.append(allocator, .{ .center = .{ 0, 1.2, 0 }, .radius = 1.2, .albedo = .{ 1, 1, 1 }, .fuzz = 0, .ior = 1.52, .emissive = 0, .mat_type = 2, .pad = 0 });

    // Left: Rich matte terracotta
    try spheres.append(allocator, .{ .center = .{ -4, 1, 0 }, .radius = 1.0, .albedo = .{ 0.8, 0.3, 0.2 }, .fuzz = 0, .ior = 0, .emissive = 0, .mat_type = 0, .pad = 0 });

    // Right: Polished gold mirror
    try spheres.append(allocator, .{ .center = .{ 4, 1, 0 }, .radius = 1.0, .albedo = .{ 1.0, 0.85, 0.57 }, .fuzz = 0.0, .ior = 0, .emissive = 0, .mat_type = 1, .pad = 0 });

    // === ACCENT SPHERES ===

    // Chrome sphere - perfect mirror
    try spheres.append(allocator, .{ .center = .{ -2, 0.5, 2 }, .radius = 0.5, .albedo = .{ 0.95, 0.95, 0.97 }, .fuzz = 0.0, .ior = 0, .emissive = 0, .mat_type = 1, .pad = 0 });

    // Copper sphere - warm metallic
    try spheres.append(allocator, .{ .center = .{ 2.5, 0.6, 1.5 }, .radius = 0.6, .albedo = .{ 0.95, 0.64, 0.54 }, .fuzz = 0.02, .ior = 0, .emissive = 0, .mat_type = 1, .pad = 0 });

    // Emerald glass
    try spheres.append(allocator, .{ .center = .{ -1.5, 0.4, -2 }, .radius = 0.4, .albedo = .{ 0.8, 1, 0.8 }, .fuzz = 0, .ior = 1.65, .emissive = 0, .mat_type = 2, .pad = 0 });

    // Sapphire glass
    try spheres.append(allocator, .{ .center = .{ 1.5, 0.45, -1.8 }, .radius = 0.45, .albedo = .{ 0.8, 0.85, 1 }, .fuzz = 0, .ior = 1.77, .emissive = 0, .mat_type = 2, .pad = 0 });

    // === DRAMATIC LIGHTING ===

    // Main soft light (sun-like, high up)
    try spheres.append(allocator, .{ .center = .{ 5, 12, -5 }, .radius = 4.0, .albedo = .{ 1.0, 0.95, 0.85 }, .fuzz = 0, .ior = 0, .emissive = 10.0, .mat_type = 3, .pad = 0 });

    // Accent blue light
    try spheres.append(allocator, .{ .center = .{ -8, 4, 3 }, .radius = 1.5, .albedo = .{ 0.4, 0.6, 1.0 }, .fuzz = 0, .ior = 0, .emissive = 6.0, .mat_type = 3, .pad = 0 });

    // Warm rim light
    try spheres.append(allocator, .{ .center = .{ 8, 3, 5 }, .radius = 1.0, .albedo = .{ 1.0, 0.6, 0.3 }, .fuzz = 0, .ior = 0, .emissive = 5.0, .mat_type = 3, .pad = 0 });

    // === MORE SHOWCASE SPHERES ===

    // Brushed steel
    try spheres.append(allocator, .{ .center = .{ -7, 1.3, -2 }, .radius = 1.3, .albedo = .{ 0.7, 0.7, 0.75 }, .fuzz = 0.15, .ior = 0, .emissive = 0, .mat_type = 1, .pad = 0 });

    // Rose gold
    try spheres.append(allocator, .{ .center = .{ 7, 0.9, 2 }, .radius = 0.9, .albedo = .{ 0.92, 0.65, 0.6 }, .fuzz = 0.03, .ior = 0, .emissive = 0, .mat_type = 1, .pad = 0 });

    // Deep blue matte
    try spheres.append(allocator, .{ .center = .{ 0, 0.7, 4 }, .radius = 0.7, .albedo = .{ 0.15, 0.2, 0.5 }, .fuzz = 0, .ior = 0, .emissive = 0, .mat_type = 0, .pad = 0 });

    // Large background glass
    try spheres.append(allocator, .{ .center = .{ -5, 2, -8 }, .radius = 2.0, .albedo = .{ 1, 1, 1 }, .fuzz = 0, .ior = 1.45, .emissive = 0, .mat_type = 2, .pad = 0 });

    // === SUBSURFACE SCATTERING SHOWCASE ===

    // Jade sphere - green SSS
    try spheres.append(allocator, .{ .center = .{ 2.5, 0.8, 2.5 }, .radius = 0.8, .albedo = .{ 0.3, 0.7, 0.4 }, .fuzz = 0.15, .ior = 0, .emissive = 0, .mat_type = 4, .pad = 0 });

    // Wax/candle - warm SSS
    try spheres.append(allocator, .{ .center = .{ -2.5, 0.6, 3 }, .radius = 0.6, .albedo = .{ 0.9, 0.7, 0.5 }, .fuzz = 0.2, .ior = 0, .emissive = 0, .mat_type = 4, .pad = 0 });

    // Skin-like - pinkish SSS
    try spheres.append(allocator, .{ .center = .{ 5, 0.7, -3 }, .radius = 0.7, .albedo = .{ 0.9, 0.6, 0.5 }, .fuzz = 0.1, .ior = 0, .emissive = 0, .mat_type = 4, .pad = 0 });

    // Marble - white with subtle SSS
    try spheres.append(allocator, .{ .center = .{ -6, 0.9, 3 }, .radius = 0.9, .albedo = .{ 0.95, 0.93, 0.9 }, .fuzz = 0.08, .ior = 0, .emissive = 0, .mat_type = 4, .pad = 0 });

    // Random spheres - now we can have more with BVH!
    var prng = std.Random.DefaultPrng.init(42);
    var rng = prng.random();

    var a: i32 = -11;
    while (a < 11) : (a += 1) {
        var b: i32 = -11;
        while (b < 11) : (b += 1) {
            const choose_mat = vec3.randomFloat(&rng);
            const center_x = @as(f32, @floatFromInt(a)) + 0.9 * vec3.randomFloat(&rng);
            const center_z = @as(f32, @floatFromInt(b)) + 0.9 * vec3.randomFloat(&rng);
            const center = Vec3.init(center_x, 0.2, center_z);

            if (center.sub(Vec3.init(4, 0.2, 0)).length() < 0.9) continue;
            if (center.sub(Vec3.init(-4, 0.2, 0)).length() < 0.9) continue;
            if (center.sub(Vec3.init(0, 0.2, 0)).length() < 0.9) continue;

            if (choose_mat < 0.65) {
                const albedo = vec3.randomVec3(&rng).mul(vec3.randomVec3(&rng));
                try spheres.append(allocator, .{ .center = .{ center_x, 0.2, center_z }, .radius = 0.2, .albedo = .{ albedo.x, albedo.y, albedo.z }, .fuzz = 0, .ior = 0, .emissive = 0, .mat_type = 0, .pad = 0 });
            } else if (choose_mat < 0.85) {
                const albedo = vec3.randomVec3Range(&rng, 0.5, 1);
                const fuzz = vec3.randomFloatRange(&rng, 0, 0.3);
                try spheres.append(allocator, .{ .center = .{ center_x, 0.2, center_z }, .radius = 0.2, .albedo = .{ albedo.x, albedo.y, albedo.z }, .fuzz = fuzz, .ior = 0, .emissive = 0, .mat_type = 1, .pad = 0 });
            } else if (choose_mat < 0.92) {
                try spheres.append(allocator, .{ .center = .{ center_x, 0.2, center_z }, .radius = 0.2, .albedo = .{ 1, 1, 1 }, .fuzz = 0, .ior = 1.5, .emissive = 0, .mat_type = 2, .pad = 0 });
            } else if (choose_mat < 0.97) {
                // SSS material - random translucent colors
                const sss_color = vec3.randomVec3Range(&rng, 0.4, 0.95);
                const scatter = vec3.randomFloatRange(&rng, 0.08, 0.25);
                try spheres.append(allocator, .{ .center = .{ center_x, 0.2, center_z }, .radius = 0.2, .albedo = .{ sss_color.x, sss_color.y, sss_color.z }, .fuzz = scatter, .ior = 0, .emissive = 0, .mat_type = 4, .pad = 0 });
            } else {
                const light_color = vec3.randomVec3Range(&rng, 0.5, 1);
                try spheres.append(allocator, .{ .center = .{ center_x, 0.2, center_z }, .radius = 0.2, .albedo = .{ light_color.x, light_color.y, light_color.z }, .fuzz = 0, .ior = 0, .emissive = 3.0, .mat_type = 3, .pad = 0 });
            }
        }
    }
}
