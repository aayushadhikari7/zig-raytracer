const std = @import("std");
const vec3 = @import("vec3.zig");
const types = @import("types.zig");

const Vec3 = vec3.Vec3;
const GPUTriangle = types.GPUTriangle;

// ============================================================================
// OBJ FILE LOADER
// ============================================================================

// Get IO instance for file operations
fn getIo() std.Io {
    return std.Io.Threaded.global_single_threaded.io();
}

pub const ObjMesh = struct {
    triangles: std.ArrayList(GPUTriangle),

    pub fn deinit(self: *ObjMesh, allocator: std.mem.Allocator) void {
        self.triangles.deinit(allocator);
    }
};

pub const ObjTransform = struct {
    scale: f32 = 1.0,
    offset: Vec3 = Vec3.init(0, 0, 0),
    albedo: [3]f32 = .{ 0.8, 0.8, 0.8 },
    mat_type: i32 = 0,
    emissive: f32 = 0.0,
    texture_id: i32 = 0, // 0=none, 1=checker, 2=brick, 3=marble, 4=wood
};

pub fn loadObj(allocator: std.mem.Allocator, path: []const u8, transform: ObjTransform) !ObjMesh {
    const io = getIo();

    var mesh = ObjMesh{
        .triangles = std.ArrayList(GPUTriangle){},
    };
    errdefer mesh.deinit(allocator);

    // Read file
    const cwd = std.Io.Dir.cwd();
    const file = cwd.openFile(io, path, .{}) catch |err| {
        std.debug.print("Failed to open OBJ file '{s}': {}\n", .{ path, err });
        return err;
    };
    defer file.close(io);

    var read_buf: [8192]u8 = undefined;
    var reader = file.reader(io, &read_buf);
    const content = reader.interface.allocRemaining(allocator, std.Io.Limit.limited(50 * 1024 * 1024)) catch |err| {
        std.debug.print("Failed to read OBJ file: {}\n", .{err});
        return err;
    };
    defer allocator.free(content);

    // Parse vertices, normals, and texture coordinates
    var vertices = std.ArrayList(Vec3){};
    defer vertices.deinit(allocator);
    var normals = std.ArrayList(Vec3){};
    defer normals.deinit(allocator);
    const Vec2 = struct { u: f32, v: f32 };
    var texcoords = std.ArrayList(Vec2){};
    defer texcoords.deinit(allocator);

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        var parts = std.mem.splitScalar(u8, trimmed, ' ');
        const cmd = parts.next() orelse continue;

        if (std.mem.eql(u8, cmd, "v")) {
            // Vertex position
            const x = std.fmt.parseFloat(f32, parts.next() orelse continue) catch continue;
            const y = std.fmt.parseFloat(f32, parts.next() orelse continue) catch continue;
            const z = std.fmt.parseFloat(f32, parts.next() orelse continue) catch continue;
            try vertices.append(allocator, Vec3.init(
                x * transform.scale + transform.offset.x,
                y * transform.scale + transform.offset.y,
                z * transform.scale + transform.offset.z,
            ));
        } else if (std.mem.eql(u8, cmd, "vt")) {
            // Texture coordinate
            const u = std.fmt.parseFloat(f32, parts.next() orelse continue) catch continue;
            const v = std.fmt.parseFloat(f32, parts.next() orelse "0") catch 0.0;
            try texcoords.append(allocator, .{ .u = u, .v = v });
        } else if (std.mem.eql(u8, cmd, "vn")) {
            // Vertex normal
            const x = std.fmt.parseFloat(f32, parts.next() orelse continue) catch continue;
            const y = std.fmt.parseFloat(f32, parts.next() orelse continue) catch continue;
            const z = std.fmt.parseFloat(f32, parts.next() orelse continue) catch continue;
            try normals.append(allocator, Vec3.init(x, y, z).normalize());
        } else if (std.mem.eql(u8, cmd, "f")) {
            // Face - collect all vertex indices
            var face_verts: [16]usize = undefined;
            var face_norms: [16]?usize = undefined;
            var face_uvs: [16]?usize = undefined;
            var face_count: usize = 0;

            while (parts.next()) |face_part| {
                if (face_part.len == 0) continue;
                if (face_count >= 16) break;

                // Parse v/vt/vn or v//vn or v
                var indices = std.mem.splitScalar(u8, face_part, '/');
                const v_str = indices.next() orelse continue;
                const v_idx = (std.fmt.parseInt(usize, v_str, 10) catch continue);
                if (v_idx == 0 or v_idx > vertices.items.len) continue;
                face_verts[face_count] = v_idx - 1;

                // Texture coordinate index (optional)
                if (indices.next()) |vt_str| {
                    if (vt_str.len > 0) {
                        const vt_idx = std.fmt.parseInt(usize, vt_str, 10) catch 0;
                        if (vt_idx > 0 and vt_idx <= texcoords.items.len) {
                            face_uvs[face_count] = vt_idx - 1;
                        } else {
                            face_uvs[face_count] = null;
                        }
                    } else {
                        face_uvs[face_count] = null;
                    }
                } else {
                    face_uvs[face_count] = null;
                }

                // Normal index (optional)
                if (indices.next()) |n_str| {
                    if (n_str.len > 0) {
                        const n_idx = std.fmt.parseInt(usize, n_str, 10) catch 0;
                        if (n_idx > 0 and n_idx <= normals.items.len) {
                            face_norms[face_count] = n_idx - 1;
                        } else {
                            face_norms[face_count] = null;
                        }
                    } else {
                        face_norms[face_count] = null;
                    }
                } else {
                    face_norms[face_count] = null;
                }

                face_count += 1;
            }

            // Triangulate face (fan triangulation)
            if (face_count >= 3) {
                var i: usize = 1;
                while (i < face_count - 1) : (i += 1) {
                    const v0 = vertices.items[face_verts[0]];
                    const v1 = vertices.items[face_verts[i]];
                    const v2 = vertices.items[face_verts[i + 1]];

                    // Calculate face normal if not provided
                    const edge1 = v1.sub(v0);
                    const edge2 = v2.sub(v0);
                    const face_normal = edge1.cross(edge2).normalize();

                    const n0 = if (face_norms[0]) |ni| normals.items[ni] else face_normal;
                    const n1 = if (face_norms[i]) |ni| normals.items[ni] else face_normal;
                    const n2 = if (face_norms[i + 1]) |ni| normals.items[ni] else face_normal;

                    // Get UV coords (default if not provided)
                    const default_uv = Vec2{ .u = 0.5, .v = 0.5 };
                    const uv0 = if (face_uvs[0]) |ti| texcoords.items[ti] else default_uv;
                    const uv1 = if (face_uvs[i]) |ti| texcoords.items[ti] else default_uv;
                    const uv2 = if (face_uvs[i + 1]) |ti| texcoords.items[ti] else default_uv;

                    try mesh.triangles.append(allocator, .{
                        .v0 = .{ v0.x, v0.y, v0.z },
                        .v1 = .{ v1.x, v1.y, v1.z },
                        .v2 = .{ v2.x, v2.y, v2.z },
                        .n0 = .{ n0.x, n0.y, n0.z },
                        .n1 = .{ n1.x, n1.y, n1.z },
                        .n2 = .{ n2.x, n2.y, n2.z },
                        .albedo = transform.albedo,
                        .mat_type = transform.mat_type,
                        .emissive = transform.emissive,
                        .pad1 = 0,
                        .pad2 = 0,
                        .pad3 = 0,
                        .pad4 = 0,
                        .pad5 = 0,
                        .uv0 = .{ uv0.u, uv0.v },
                        .uv1 = .{ uv1.u, uv1.v },
                        .uv2 = .{ uv2.u, uv2.v },
                        .texture_id = transform.texture_id,
                        .pad_uv = 0,
                    });
                }
            }
        }
    }

    std.debug.print("Loaded OBJ '{s}': {} vertices, {} normals, {} texcoords, {} triangles\n", .{ path, vertices.items.len, normals.items.len, texcoords.items.len, mesh.triangles.items.len });
    return mesh;
}

// ============================================================================
// ICOSPHERE GENERATOR
// ============================================================================

pub const IcosphereMaterial = struct {
    albedo: [3]f32,
    mat_type: i32,
    emissive: f32,
};

pub fn createIcosphere(allocator: std.mem.Allocator, triangles: *std.ArrayList(GPUTriangle), center: Vec3, radius: f32, subdivisions: u32, material: IcosphereMaterial) !void {
    // Golden ratio for icosahedron
    const phi: f32 = (1.0 + @sqrt(5.0)) / 2.0;
    const a: f32 = 1.0;
    const b: f32 = 1.0 / phi;

    // Icosahedron vertices (normalized)
    const base_verts = [12]Vec3{
        Vec3.init(0, b, -a).normalize(),
        Vec3.init(b, a, 0).normalize(),
        Vec3.init(-b, a, 0).normalize(),
        Vec3.init(0, b, a).normalize(),
        Vec3.init(0, -b, a).normalize(),
        Vec3.init(-a, 0, b).normalize(),
        Vec3.init(0, -b, -a).normalize(),
        Vec3.init(a, 0, -b).normalize(),
        Vec3.init(a, 0, b).normalize(),
        Vec3.init(-a, 0, -b).normalize(),
        Vec3.init(b, -a, 0).normalize(),
        Vec3.init(-b, -a, 0).normalize(),
    };

    // Icosahedron faces (20 triangles)
    const faces = [20][3]u8{
        .{ 2, 1, 0 },  .{ 1, 2, 3 },  .{ 5, 4, 3 },  .{ 4, 8, 3 },
        .{ 7, 6, 0 },  .{ 6, 9, 0 },  .{ 11, 10, 4 }, .{ 10, 11, 6 },
        .{ 9, 5, 2 },  .{ 5, 9, 11 }, .{ 8, 7, 1 },  .{ 7, 8, 10 },
        .{ 2, 5, 3 },  .{ 8, 1, 3 },  .{ 9, 2, 0 },  .{ 1, 7, 0 },
        .{ 11, 9, 6 }, .{ 7, 10, 6 }, .{ 5, 11, 4 }, .{ 10, 8, 4 },
    };

    // Generate all triangles
    for (faces) |face| {
        try subdivideTriangle(allocator, triangles, base_verts[face[0]], base_verts[face[1]], base_verts[face[2]], subdivisions, center, radius, material);
    }
}

fn subdivideTriangle(allocator: std.mem.Allocator, tris: *std.ArrayList(GPUTriangle), v0: Vec3, v1: Vec3, v2: Vec3, depth: u32, c: Vec3, r: f32, mat: IcosphereMaterial) !void {
    if (depth == 0) {
        // Add final triangle
        const p0 = c.add(v0.scale(r));
        const p1 = c.add(v1.scale(r));
        const p2 = c.add(v2.scale(r));
        // Generate spherical UVs from normals
        const pi = 3.14159265;
        const uv_0 = .{ 0.5 + std.math.atan2(v0.z, v0.x) / (2.0 * pi), 0.5 - std.math.asin(v0.y) / pi };
        const uv_1 = .{ 0.5 + std.math.atan2(v1.z, v1.x) / (2.0 * pi), 0.5 - std.math.asin(v1.y) / pi };
        const uv_2 = .{ 0.5 + std.math.atan2(v2.z, v2.x) / (2.0 * pi), 0.5 - std.math.asin(v2.y) / pi };
        try tris.append(allocator, .{
            .v0 = .{ p0.x, p0.y, p0.z },
            .v1 = .{ p1.x, p1.y, p1.z },
            .v2 = .{ p2.x, p2.y, p2.z },
            .n0 = .{ v0.x, v0.y, v0.z },
            .n1 = .{ v1.x, v1.y, v1.z },
            .n2 = .{ v2.x, v2.y, v2.z },
            .albedo = mat.albedo,
            .mat_type = mat.mat_type,
            .emissive = mat.emissive,
            .pad1 = 0,
            .pad2 = 0,
            .pad3 = 0,
            .pad4 = 0,
            .pad5 = 0,
            .uv0 = uv_0,
            .uv1 = uv_1,
            .uv2 = uv_2,
            .texture_id = 0, // No texture by default for icospheres
            .pad_uv = 0,
        });
    } else {
        // Subdivide
        const m01 = v0.add(v1).scale(0.5).normalize();
        const m12 = v1.add(v2).scale(0.5).normalize();
        const m20 = v2.add(v0).scale(0.5).normalize();
        try subdivideTriangle(allocator, tris, v0, m01, m20, depth - 1, c, r, mat);
        try subdivideTriangle(allocator, tris, m01, v1, m12, depth - 1, c, r, mat);
        try subdivideTriangle(allocator, tris, m20, m12, v2, depth - 1, c, r, mat);
        try subdivideTriangle(allocator, tris, m01, m12, m20, depth - 1, c, r, mat);
    }
}
