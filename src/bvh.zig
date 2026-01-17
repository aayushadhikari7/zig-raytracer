const std = @import("std");
const vec3 = @import("vec3.zig");
const types = @import("types.zig");

const Vec3 = vec3.Vec3;
const GPUSphere = types.GPUSphere;
const GPUTriangle = types.GPUTriangle;
const GPUBVHNode = types.GPUBVHNode;
const AABB = types.AABB;

// ============================================================================
// BVH CONSTRUCTION - Builds acceleration structures for spheres and triangles
// ============================================================================

pub fn buildBVH(
    allocator: std.mem.Allocator,
    spheres: []const GPUSphere,
    indices: []u32,
    nodes: *std.ArrayList(GPUBVHNode),
) !u32 {
    const node_idx: u32 = @intCast(nodes.items.len);
    try nodes.append(allocator, undefined);

    if (indices.len == 1) {
        // Leaf node
        const s = spheres[indices[0]];
        var aabb = AABB.empty();
        aabb.expandSphere(Vec3.init(s.center[0], s.center[1], s.center[2]), s.radius);

        nodes.items[node_idx] = .{
            .aabb_min = .{ aabb.min.x, aabb.min.y, aabb.min.z },
            .left_child = -1,
            .aabb_max = .{ aabb.max.x, aabb.max.y, aabb.max.z },
            .right_child = @intCast(indices[0]),
        };
        return node_idx;
    }

    // Compute bounding box of all spheres
    var bounds = AABB.empty();
    for (indices) |idx| {
        const s = spheres[idx];
        bounds.expandSphere(Vec3.init(s.center[0], s.center[1], s.center[2]), s.radius);
    }

    // Find longest axis
    const extent = Vec3.init(
        bounds.max.x - bounds.min.x,
        bounds.max.y - bounds.min.y,
        bounds.max.z - bounds.min.z,
    );
    var axis: usize = 0;
    if (extent.y > extent.x) axis = 1;
    if (extent.z > (if (axis == 0) extent.x else extent.y)) axis = 2;

    // Sort by axis
    const SortContext = struct {
        spheres: []const GPUSphere,
        axis: usize,
    };
    const ctx = SortContext{ .spheres = spheres, .axis = axis };

    std.mem.sort(u32, indices, ctx, struct {
        fn lessThan(c: SortContext, a: u32, b: u32) bool {
            const ca = c.spheres[a].center[c.axis];
            const cb = c.spheres[b].center[c.axis];
            return ca < cb;
        }
    }.lessThan);

    // Split in half
    const mid = indices.len / 2;
    const left_idx = try buildBVH(allocator, spheres, indices[0..mid], nodes);
    const right_idx = try buildBVH(allocator, spheres, indices[mid..], nodes);

    // Merge bounds from children
    const left_node = nodes.items[left_idx];
    const right_node = nodes.items[right_idx];
    const left_aabb = AABB{
        .min = Vec3.init(left_node.aabb_min[0], left_node.aabb_min[1], left_node.aabb_min[2]),
        .max = Vec3.init(left_node.aabb_max[0], left_node.aabb_max[1], left_node.aabb_max[2]),
    };
    const right_aabb = AABB{
        .min = Vec3.init(right_node.aabb_min[0], right_node.aabb_min[1], right_node.aabb_min[2]),
        .max = Vec3.init(right_node.aabb_max[0], right_node.aabb_max[1], right_node.aabb_max[2]),
    };
    const merged = AABB.merge(left_aabb, right_aabb);

    nodes.items[node_idx] = .{
        .aabb_min = .{ merged.min.x, merged.min.y, merged.min.z },
        .left_child = @intCast(left_idx),
        .aabb_max = .{ merged.max.x, merged.max.y, merged.max.z },
        .right_child = @intCast(right_idx),
    };

    return node_idx;
}

pub fn buildTriangleBVH(
    allocator: std.mem.Allocator,
    triangles: []const GPUTriangle,
    indices: []u32,
    nodes: *std.ArrayList(GPUBVHNode),
) !u32 {
    const node_idx: u32 = @intCast(nodes.items.len);
    try nodes.append(allocator, undefined);

    if (indices.len == 1) {
        // Leaf node
        var aabb = AABB.empty();
        aabb.expandTriangle(triangles[indices[0]]);

        nodes.items[node_idx] = .{
            .aabb_min = .{ aabb.min.x, aabb.min.y, aabb.min.z },
            .left_child = -1,
            .aabb_max = .{ aabb.max.x, aabb.max.y, aabb.max.z },
            .right_child = @intCast(indices[0]),
        };
        return node_idx;
    }

    // Compute bounding box of all triangles
    var bounds = AABB.empty();
    for (indices) |idx| {
        bounds.expandTriangle(triangles[idx]);
    }

    // Find longest axis
    const extent = Vec3.init(
        bounds.max.x - bounds.min.x,
        bounds.max.y - bounds.min.y,
        bounds.max.z - bounds.min.z,
    );
    var axis: usize = 0;
    if (extent.y > extent.x) axis = 1;
    if (extent.z > (if (axis == 0) extent.x else extent.y)) axis = 2;

    // Sort by centroid along axis
    const SortContext = struct {
        triangles: []const GPUTriangle,
        axis: usize,
    };
    const ctx = SortContext{ .triangles = triangles, .axis = axis };

    std.mem.sort(u32, indices, ctx, struct {
        fn lessThan(c: SortContext, a: u32, b: u32) bool {
            const ta = c.triangles[a];
            const tb = c.triangles[b];
            const ca = (ta.v0[c.axis] + ta.v1[c.axis] + ta.v2[c.axis]) / 3.0;
            const cb = (tb.v0[c.axis] + tb.v1[c.axis] + tb.v2[c.axis]) / 3.0;
            return ca < cb;
        }
    }.lessThan);

    // Split in half
    const mid = indices.len / 2;
    const left_idx = try buildTriangleBVH(allocator, triangles, indices[0..mid], nodes);
    const right_idx = try buildTriangleBVH(allocator, triangles, indices[mid..], nodes);

    // Merge bounds from children
    const left_node = nodes.items[left_idx];
    const right_node = nodes.items[right_idx];
    const left_aabb = AABB{
        .min = Vec3.init(left_node.aabb_min[0], left_node.aabb_min[1], left_node.aabb_min[2]),
        .max = Vec3.init(left_node.aabb_max[0], left_node.aabb_max[1], left_node.aabb_max[2]),
    };
    const right_aabb = AABB{
        .min = Vec3.init(right_node.aabb_min[0], right_node.aabb_min[1], right_node.aabb_min[2]),
        .max = Vec3.init(right_node.aabb_max[0], right_node.aabb_max[1], right_node.aabb_max[2]),
    };
    const merged = AABB.merge(left_aabb, right_aabb);

    nodes.items[node_idx] = .{
        .aabb_min = .{ merged.min.x, merged.min.y, merged.min.z },
        .left_child = @intCast(left_idx),
        .aabb_max = .{ merged.max.x, merged.max.y, merged.max.z },
        .right_child = @intCast(right_idx),
    };

    return node_idx;
}
