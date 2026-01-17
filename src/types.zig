const std = @import("std");
const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;

// ============================================================================
// GPU DATA STRUCTURES - Must match GLSL layout (std430)
// ============================================================================

pub const GPUSphere = extern struct {
    center: [3]f32,
    radius: f32,
    albedo: [3]f32,
    fuzz: f32,
    ior: f32,
    emissive: f32,
    mat_type: i32, // 0=diffuse, 1=metal, 2=glass, 3=emissive, 4=SSS
    pad: f32,
};

pub const GPUTriangle = extern struct {
    v0: [3]f32,
    mat_type: i32,
    v1: [3]f32,
    pad1: f32,
    v2: [3]f32,
    pad2: f32,
    n0: [3]f32,
    pad3: f32,
    n1: [3]f32,
    pad4: f32,
    n2: [3]f32,
    pad5: f32,
    albedo: [3]f32,
    emissive: f32,
    // UV coordinates for texture mapping
    uv0: [2]f32,
    uv1: [2]f32,
    uv2: [2]f32,
    texture_id: i32, // 0=none, 1=checker, 2=brick, 3=marble, 4=wood
    pad_uv: i32,
};

pub const GPUBVHNode = extern struct {
    aabb_min: [3]f32,
    left_child: i32, // -1 if leaf node
    aabb_max: [3]f32,
    right_child: i32, // sphere/triangle index if leaf
};

// ============================================================================
// AABB - Axis-Aligned Bounding Box for BVH construction
// ============================================================================

pub const AABB = struct {
    min: Vec3,
    max: Vec3,

    pub fn empty() AABB {
        return .{
            .min = Vec3.init(std.math.inf(f32), std.math.inf(f32), std.math.inf(f32)),
            .max = Vec3.init(-std.math.inf(f32), -std.math.inf(f32), -std.math.inf(f32)),
        };
    }

    pub fn expandSphere(self: *AABB, center: Vec3, radius: f32) void {
        self.min = Vec3.init(
            @min(self.min.x, center.x - radius),
            @min(self.min.y, center.y - radius),
            @min(self.min.z, center.z - radius),
        );
        self.max = Vec3.init(
            @max(self.max.x, center.x + radius),
            @max(self.max.y, center.y + radius),
            @max(self.max.z, center.z + radius),
        );
    }

    pub fn expandTriangle(self: *AABB, tri: GPUTriangle) void {
        // Expand to include all three vertices
        self.min = Vec3.init(
            @min(@min(@min(self.min.x, tri.v0[0]), tri.v1[0]), tri.v2[0]),
            @min(@min(@min(self.min.y, tri.v0[1]), tri.v1[1]), tri.v2[1]),
            @min(@min(@min(self.min.z, tri.v0[2]), tri.v1[2]), tri.v2[2]),
        );
        self.max = Vec3.init(
            @max(@max(@max(self.max.x, tri.v0[0]), tri.v1[0]), tri.v2[0]),
            @max(@max(@max(self.max.y, tri.v0[1]), tri.v1[1]), tri.v2[1]),
            @max(@max(@max(self.max.z, tri.v0[2]), tri.v1[2]), tri.v2[2]),
        );
    }

    pub fn triangleCenter(tri: GPUTriangle) Vec3 {
        return Vec3.init(
            (tri.v0[0] + tri.v1[0] + tri.v2[0]) / 3.0,
            (tri.v0[1] + tri.v1[1] + tri.v2[1]) / 3.0,
            (tri.v0[2] + tri.v1[2] + tri.v2[2]) / 3.0,
        );
    }

    pub fn merge(a: AABB, b: AABB) AABB {
        return .{
            .min = Vec3.init(@min(a.min.x, b.min.x), @min(a.min.y, b.min.y), @min(a.min.z, b.min.z)),
            .max = Vec3.init(@max(a.max.x, b.max.x), @max(a.max.y, b.max.y), @max(a.max.z, b.max.z)),
        };
    }
};
