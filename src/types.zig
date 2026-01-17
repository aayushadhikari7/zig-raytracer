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

// CSG primitive types
pub const CSG_PRIM_SPHERE: i32 = 0;
pub const CSG_PRIM_BOX: i32 = 1;
pub const CSG_PRIM_CYLINDER: i32 = 2;
pub const CSG_PRIM_TORUS: i32 = 3;

// CSG operation types
pub const CSG_OP_UNION: i32 = 0;
pub const CSG_OP_INTERSECT: i32 = 1;
pub const CSG_OP_SUBTRACT: i32 = 2;
pub const CSG_OP_SMOOTH_UNION: i32 = 3;

// CSG primitive - basic shape for CSG operations
pub const GPUCSGPrimitive = extern struct {
    // Position and size
    center: [3]f32,
    prim_type: i32, // 0=sphere, 1=box, 2=cylinder, 3=torus
    size: [3]f32, // radius for sphere, half-extents for box, (radius, height, 0) for cylinder
    pad0: f32,
    // Rotation (euler angles in radians)
    rotation: [3]f32,
    pad1: f32,
};

// CSG object - combines primitives with boolean operations
pub const GPUCSGObject = extern struct {
    prim_a: i32, // Index of first primitive (or -1 if referencing another CSG object)
    prim_b: i32, // Index of second primitive
    operation: i32, // 0=union, 1=intersect, 2=subtract, 3=smooth_union
    smooth_k: f32, // Smoothness factor for smooth operations
    // Material properties
    albedo: [3]f32,
    mat_type: i32,
    fuzz: f32,
    ior: f32,
    emissive: f32,
    pad: f32,
};

// Mesh instance for instanced rendering
// Contains a 4x4 transform matrix and mesh reference
pub const GPUMeshInstance = extern struct {
    // Transform matrix (row-major) - 4 rows of vec4
    transform_row0: [4]f32, // First row
    transform_row1: [4]f32, // Second row
    transform_row2: [4]f32, // Third row
    transform_row3: [4]f32, // Fourth row (translation in xyz, 1 in w)
    // INVERSE transform matrix (pre-computed to avoid per-ray inversion!)
    inv_transform_row0: [4]f32,
    inv_transform_row1: [4]f32,
    inv_transform_row2: [4]f32,
    inv_transform_row3: [4]f32,
    // Inverse transpose for normals (upper 3x3)
    normal_row0: [3]f32,
    mesh_start: i32, // Start index in triangle buffer
    normal_row1: [3]f32,
    mesh_end: i32, // End index in triangle buffer
    normal_row2: [3]f32,
    mesh_bvh_root: i32, // Root index into mesh BVH nodes (-1 if no BVH)
};

// Rectangular area light for soft shadows
pub const GPUAreaLight = extern struct {
    position: [3]f32, // Corner position
    pad0: f32,
    u_vec: [3]f32, // First edge vector
    pad1: f32,
    v_vec: [3]f32, // Second edge vector
    pad2: f32,
    normal: [3]f32, // Light normal (pointing outward)
    area: f32, // Pre-computed area for PDF
    color: [3]f32, // Light color
    intensity: f32, // Light intensity
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

    // Transform AABB by a matrix (returns conservative bounds)
    pub fn transform(self: AABB, m: [4][4]f32) AABB {
        // Use the 8 corners approach for conservative AABB
        var result = AABB.empty();
        const corners = [8]Vec3{
            Vec3.init(self.min.x, self.min.y, self.min.z),
            Vec3.init(self.max.x, self.min.y, self.min.z),
            Vec3.init(self.min.x, self.max.y, self.min.z),
            Vec3.init(self.max.x, self.max.y, self.min.z),
            Vec3.init(self.min.x, self.min.y, self.max.z),
            Vec3.init(self.max.x, self.min.y, self.max.z),
            Vec3.init(self.min.x, self.max.y, self.max.z),
            Vec3.init(self.max.x, self.max.y, self.max.z),
        };
        for (corners) |c| {
            const tx = m[0][0] * c.x + m[0][1] * c.y + m[0][2] * c.z + m[0][3];
            const ty = m[1][0] * c.x + m[1][1] * c.y + m[1][2] * c.z + m[1][3];
            const tz = m[2][0] * c.x + m[2][1] * c.y + m[2][2] * c.z + m[2][3];
            result.min = Vec3.init(@min(result.min.x, tx), @min(result.min.y, ty), @min(result.min.z, tz));
            result.max = Vec3.init(@max(result.max.x, tx), @max(result.max.y, ty), @max(result.max.z, tz));
        }
        return result;
    }
};

// Helper to create identity matrix
pub fn identityMatrix() [4][4]f32 {
    return .{
        .{ 1, 0, 0, 0 },
        .{ 0, 1, 0, 0 },
        .{ 0, 0, 1, 0 },
        .{ 0, 0, 0, 1 },
    };
}

// Create translation matrix
pub fn translationMatrix(x: f32, y: f32, z: f32) [4][4]f32 {
    return .{
        .{ 1, 0, 0, x },
        .{ 0, 1, 0, y },
        .{ 0, 0, 1, z },
        .{ 0, 0, 0, 1 },
    };
}

// Create scale matrix
pub fn scaleMatrix(sx: f32, sy: f32, sz: f32) [4][4]f32 {
    return .{
        .{ sx, 0, 0, 0 },
        .{ 0, sy, 0, 0 },
        .{ 0, 0, sz, 0 },
        .{ 0, 0, 0, 1 },
    };
}

// Create rotation matrix around Y axis
pub fn rotationYMatrix(angle: f32) [4][4]f32 {
    const c = @cos(angle);
    const s = @sin(angle);
    return .{
        .{ c, 0, s, 0 },
        .{ 0, 1, 0, 0 },
        .{ -s, 0, c, 0 },
        .{ 0, 0, 0, 1 },
    };
}

// Multiply two 4x4 matrices
pub fn multiplyMatrix(a: [4][4]f32, b: [4][4]f32) [4][4]f32 {
    var result: [4][4]f32 = undefined;
    for (0..4) |i| {
        for (0..4) |j| {
            result[i][j] = a[i][0] * b[0][j] + a[i][1] * b[1][j] + a[i][2] * b[2][j] + a[i][3] * b[3][j];
        }
    }
    return result;
}

// Compute inverse transpose of upper 3x3 for normal transformation
pub fn normalMatrix(m: [4][4]f32) [3][3]f32 {
    // For rotation + uniform scale, normal matrix is just the upper 3x3
    // For non-uniform scale, we need proper inverse transpose
    const det = m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1]) -
        m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0]) +
        m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0]);

    if (@abs(det) < 1e-10) {
        return .{
            .{ 1, 0, 0 },
            .{ 0, 1, 0 },
            .{ 0, 0, 1 },
        };
    }

    const inv_det = 1.0 / det;
    return .{
        .{
            (m[1][1] * m[2][2] - m[1][2] * m[2][1]) * inv_det,
            (m[0][2] * m[2][1] - m[0][1] * m[2][2]) * inv_det,
            (m[0][1] * m[1][2] - m[0][2] * m[1][1]) * inv_det,
        },
        .{
            (m[1][2] * m[2][0] - m[1][0] * m[2][2]) * inv_det,
            (m[0][0] * m[2][2] - m[0][2] * m[2][0]) * inv_det,
            (m[0][2] * m[1][0] - m[0][0] * m[1][2]) * inv_det,
        },
        .{
            (m[1][0] * m[2][1] - m[1][1] * m[2][0]) * inv_det,
            (m[0][1] * m[2][0] - m[0][0] * m[2][1]) * inv_det,
            (m[0][0] * m[1][1] - m[0][1] * m[1][0]) * inv_det,
        },
    };
}

// Compute inverse of a 4x4 matrix (for pre-computing instance inverse transforms)
pub fn inverseMatrix4x4(m: [4][4]f32) [4][4]f32 {
    const a00 = m[0][0]; const a01 = m[0][1]; const a02 = m[0][2]; const a03 = m[0][3];
    const a10 = m[1][0]; const a11 = m[1][1]; const a12 = m[1][2]; const a13 = m[1][3];
    const a20 = m[2][0]; const a21 = m[2][1]; const a22 = m[2][2]; const a23 = m[2][3];
    const a30 = m[3][0]; const a31 = m[3][1]; const a32 = m[3][2]; const a33 = m[3][3];

    const b00 = a00 * a11 - a01 * a10;
    const b01 = a00 * a12 - a02 * a10;
    const b02 = a00 * a13 - a03 * a10;
    const b03 = a01 * a12 - a02 * a11;
    const b04 = a01 * a13 - a03 * a11;
    const b05 = a02 * a13 - a03 * a12;
    const b06 = a20 * a31 - a21 * a30;
    const b07 = a20 * a32 - a22 * a30;
    const b08 = a20 * a33 - a23 * a30;
    const b09 = a21 * a32 - a22 * a31;
    const b10 = a21 * a33 - a23 * a31;
    const b11 = a22 * a33 - a23 * a32;

    const det = b00 * b11 - b01 * b10 + b02 * b09 + b03 * b08 - b04 * b07 + b05 * b06;
    if (@abs(det) < 0.00001) return .{
        .{1, 0, 0, 0},
        .{0, 1, 0, 0},
        .{0, 0, 1, 0},
        .{0, 0, 0, 1},
    };

    const inv_det = 1.0 / det;

    return .{
        .{
            (a11 * b11 - a12 * b10 + a13 * b09) * inv_det,
            (a02 * b10 - a01 * b11 - a03 * b09) * inv_det,
            (a31 * b05 - a32 * b04 + a33 * b03) * inv_det,
            (a22 * b04 - a21 * b05 - a23 * b03) * inv_det,
        },
        .{
            (a12 * b08 - a10 * b11 - a13 * b07) * inv_det,
            (a00 * b11 - a02 * b08 + a03 * b07) * inv_det,
            (a32 * b02 - a30 * b05 - a33 * b01) * inv_det,
            (a20 * b05 - a22 * b02 + a23 * b01) * inv_det,
        },
        .{
            (a10 * b10 - a11 * b08 + a13 * b06) * inv_det,
            (a01 * b08 - a00 * b10 - a03 * b06) * inv_det,
            (a30 * b04 - a31 * b02 + a33 * b00) * inv_det,
            (a21 * b02 - a20 * b04 - a23 * b00) * inv_det,
        },
        .{
            (a11 * b07 - a10 * b09 - a12 * b06) * inv_det,
            (a00 * b09 - a01 * b07 + a02 * b06) * inv_det,
            (a31 * b01 - a30 * b03 - a32 * b00) * inv_det,
            (a20 * b03 - a21 * b01 + a22 * b00) * inv_det,
        },
    };
}

// Create a mesh instance from a transform matrix and mesh range
pub fn createInstance(transform_mat: [4][4]f32, mesh_start: i32, mesh_end: i32, mesh_bvh_root: i32) GPUMeshInstance {
    const nm = normalMatrix(transform_mat);
    const inv = inverseMatrix4x4(transform_mat);
    return .{
        .transform_row0 = transform_mat[0],
        .transform_row1 = transform_mat[1],
        .transform_row2 = transform_mat[2],
        .transform_row3 = transform_mat[3],
        .inv_transform_row0 = inv[0],
        .inv_transform_row1 = inv[1],
        .inv_transform_row2 = inv[2],
        .inv_transform_row3 = inv[3],
        .normal_row0 = nm[0],
        .mesh_start = mesh_start,
        .normal_row1 = nm[1],
        .mesh_end = mesh_end,
        .normal_row2 = nm[2],
        .mesh_bvh_root = mesh_bvh_root,
    };
}
