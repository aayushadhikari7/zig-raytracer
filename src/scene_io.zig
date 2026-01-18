const std = @import("std");
const types = @import("types.zig");

const GPUSphere = types.GPUSphere;

// ============================================================================
// SCENE SERIALIZATION - Save/Load scenes as JSON
// ============================================================================

// Get IO instance for file operations
fn getIo() std.Io {
    return std.Io.Threaded.global_single_threaded.io();
}

pub const SceneData = struct {
    version: []const u8 = "1.0",
    name: []const u8 = "Untitled Scene",

    // Camera
    camera: CameraData = .{},

    // Objects
    spheres: []const SphereData = &.{},

    // Render settings
    settings: RenderSettings = .{},
};

pub const CameraData = struct {
    position: [3]f32 = .{ 13, 2, 3 },
    yaw: f32 = 0,
    pitch: f32 = -0.15,
    roll: f32 = 0,
    fov: f32 = 20,
    aperture: f32 = 0,
    focus_dist: f32 = 10,
    flight_mode: bool = false,
};

pub const SphereData = struct {
    name: []const u8 = "Sphere",
    center: [3]f32,
    radius: f32,
    albedo: [3]f32,
    material: MaterialType,
    fuzz: f32 = 0,
    ior: f32 = 1.5,
    emissive: f32 = 0,
};

pub const MaterialType = enum {
    diffuse,
    metal,
    glass,
    emissive,
    sss,
};

pub const RenderSettings = struct {
    samples_per_frame: u32 = 2,
    max_depth: u32 = 4,
    width: u32 = 1920,
    height: u32 = 1080,
};

// Convert GPUSphere to serializable format
pub fn sphereToData(sphere: GPUSphere, name: []const u8) SphereData {
    return .{
        .name = name,
        .center = sphere.center,
        .radius = sphere.radius,
        .albedo = sphere.albedo,
        .material = switch (sphere.mat_type) {
            0 => .diffuse,
            1 => .metal,
            2 => .glass,
            3 => .emissive,
            4 => .sss,
            else => .diffuse,
        },
        .fuzz = sphere.fuzz,
        .ior = sphere.ior,
        .emissive = sphere.emissive,
    };
}

// Convert serializable format back to GPUSphere
pub fn dataToSphere(data: SphereData) GPUSphere {
    return .{
        .center = data.center,
        .radius = data.radius,
        .albedo = data.albedo,
        .fuzz = data.fuzz,
        .ior = data.ior,
        .emissive = data.emissive,
        .mat_type = switch (data.material) {
            .diffuse => 0,
            .metal => 1,
            .glass => 2,
            .emissive => 3,
            .sss => 4,
        },
        .pad = 0,
    };
}

// Save scene to JSON file
pub fn saveScene(
    allocator: std.mem.Allocator,
    path: []const u8,
    spheres: []const GPUSphere,
    camera_pos: [3]f32,
    camera_yaw: f32,
    camera_pitch: f32,
    camera_roll: f32,
    camera_fov: f32,
    camera_aperture: f32,
    camera_focus: f32,
    flight_mode: bool,
    samples: u32,
) !void {
    const io = getIo();

    // Convert spheres to serializable format
    var sphere_data = try allocator.alloc(SphereData, spheres.len);
    defer allocator.free(sphere_data);

    var name_buf: [32]u8 = undefined;
    for (spheres, 0..) |s, i| {
        const name = std.fmt.bufPrint(&name_buf, "Object_{}", .{i}) catch "Object";
        sphere_data[i] = sphereToData(s, name);
    }

    // Extract basename from path
    const basename = std.Io.Dir.path.basename(path);

    const scene = SceneData{
        .version = "1.0",
        .name = basename,
        .camera = .{
            .position = camera_pos,
            .yaw = camera_yaw,
            .pitch = camera_pitch,
            .roll = camera_roll,
            .fov = camera_fov,
            .aperture = camera_aperture,
            .focus_dist = camera_focus,
            .flight_mode = flight_mode,
        },
        .spheres = sphere_data,
        .settings = .{
            .samples_per_frame = samples,
        },
    };

    // Write to file using Stringify
    var out: std.Io.Writer.Allocating = .init(allocator);
    defer out.deinit();
    var write_stream: std.json.Stringify = .{
        .writer = &out.writer,
        .options = .{ .whitespace = .indent_2 },
    };
    try write_stream.write(scene);

    // Create file and write
    const cwd = std.Io.Dir.cwd();
    const file = try cwd.createFile(io, path, .{});
    defer file.close(io);

    try file.writeStreamingAll(io, out.written());

    std.debug.print("Scene saved: {s} ({} objects)\n", .{ path, spheres.len });
}

// Load scene from JSON file
pub fn loadScene(
    allocator: std.mem.Allocator,
    path: []const u8,
    spheres: *std.ArrayList(GPUSphere),
    camera_pos: *[3]f32,
    camera_yaw: *f32,
    camera_pitch: *f32,
    camera_roll: *f32,
    camera_fov: *f32,
    camera_aperture: *f32,
    camera_focus: *f32,
    flight_mode: *bool,
    samples: *u32,
) !void {
    const io = getIo();
    const cwd = std.Io.Dir.cwd();

    const file = try cwd.openFile(io, path, .{});
    defer file.close(io);

    var read_buf: [8192]u8 = undefined;
    var reader = file.reader(io, &read_buf);
    const content = try reader.interface.allocRemaining(allocator, std.Io.Limit.limited(10 * 1024 * 1024)); // 10MB max
    defer allocator.free(content);

    const parsed = try std.json.parseFromSlice(SceneData, allocator, content, .{
        .ignore_unknown_fields = true,
    });
    defer parsed.deinit();

    const scene = parsed.value;

    // Apply camera
    camera_pos.* = scene.camera.position;
    camera_yaw.* = scene.camera.yaw;
    camera_pitch.* = scene.camera.pitch;
    camera_roll.* = scene.camera.roll;
    camera_fov.* = scene.camera.fov;
    camera_aperture.* = scene.camera.aperture;
    camera_focus.* = scene.camera.focus_dist;
    flight_mode.* = scene.camera.flight_mode;
    samples.* = scene.settings.samples_per_frame;

    // Clear and load spheres
    spheres.clearRetainingCapacity();
    for (scene.spheres) |s| {
        try spheres.append(allocator, dataToSphere(s));
    }

    std.debug.print("Scene loaded: {s} ({} objects)\n", .{ path, scene.spheres.len });
}

// Create a new empty scene
pub fn newScene(
    spheres: *std.ArrayList(GPUSphere),
    camera_pos: *[3]f32,
    camera_yaw: *f32,
    camera_pitch: *f32,
    camera_roll: *f32,
    camera_fov: *f32,
    camera_aperture: *f32,
    camera_focus: *f32,
    flight_mode: *bool,
) void {
    spheres.clearRetainingCapacity();

    // Reset camera
    camera_pos.* = .{ 13, 2, 3 };
    camera_yaw.* = 0;
    camera_pitch.* = -0.15;
    camera_roll.* = 0;
    camera_fov.* = 20;
    camera_aperture.* = 0;
    camera_focus.* = 10;
    flight_mode.* = false;

    std.debug.print("New scene created\n", .{});
}
