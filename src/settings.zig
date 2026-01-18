const std = @import("std");

// ============================================================================
// SETTINGS SYSTEM - Persistent configuration
// ============================================================================

// Get IO instance for file operations
fn getIo() std.Io {
    return std.Io.Threaded.global_single_threaded.io();
}

pub const Settings = struct {
    // Window
    window_width: u32 = 1920,
    window_height: u32 = 1080,
    fullscreen: bool = false,

    // Camera defaults
    camera_fov: f32 = 20.0,
    camera_aperture: f32 = 0.0,
    camera_focus_dist: f32 = 10.0,

    // Quality
    samples_per_frame: u32 = 2,
    max_depth: u32 = 4,

    // Effects (defaults)
    bloom_strength: f32 = 0.15,
    exposure: f32 = 2.0,
    chromatic_strength: f32 = 0.003,
    vignette_strength: f32 = 0.15,
    motion_blur_strength: f32 = 0.5,
    denoise_strength: f32 = 0.5,

    // UI
    show_hud: bool = true,
    show_console: bool = false,
    show_fps: bool = true,

    // Last session
    last_scene_path: ?[]const u8 = null,
    last_export_path: ?[]const u8 = null,

    // Recent files (up to 10)
    recent_files: [10]?[]const u8 = .{null} ** 10,
};

pub var current: Settings = .{};

const SETTINGS_FILE = "settings.json";

pub fn getSettingsPath(allocator: std.mem.Allocator) ![]u8 {
    // Get executable directory - use process args or current dir
    return try allocator.dupe(u8, SETTINGS_FILE);
}

pub fn load(allocator: std.mem.Allocator) !void {
    const io = getIo();
    const path = try getSettingsPath(allocator);
    defer allocator.free(path);

    const cwd = std.Io.Dir.cwd();
    const file = cwd.openFile(io, path, .{}) catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print("Settings file not found, using defaults\n", .{});
            return;
        }
        return err;
    };
    defer file.close(io);

    var read_buf: [4096]u8 = undefined;
    var reader = file.reader(io, &read_buf);
    const content = try reader.interface.allocRemaining(allocator, std.Io.Limit.limited(1024 * 1024));
    defer allocator.free(content);

    const parsed = std.json.parseFromSlice(Settings, allocator, content, .{}) catch |err| {
        std.debug.print("Failed to parse settings: {}\n", .{err});
        return;
    };
    defer parsed.deinit();

    current = parsed.value;
    std.debug.print("Settings loaded successfully\n", .{});
}

pub fn save(allocator: std.mem.Allocator) !void {
    const io = getIo();
    const path = try getSettingsPath(allocator);
    defer allocator.free(path);

    // Build JSON output
    var out: std.Io.Writer.Allocating = .init(allocator);
    defer out.deinit();
    var write_stream: std.json.Stringify = .{
        .writer = &out.writer,
        .options = .{ .whitespace = .indent_2 },
    };
    try write_stream.write(current);

    const cwd = std.Io.Dir.cwd();
    const file = try cwd.createFile(io, path, .{});
    defer file.close(io);

    try file.writeStreamingAll(io, out.written());
    std.debug.print("Settings saved to {s}\n", .{path});
}

// Apply settings to global variables (call after load)
pub fn applyToGlobals(
    fov: *f32,
    aperture: *f32,
    focus_dist: *f32,
    samples: *u32,
    bloom: *f32,
    exposure: *f32,
    chromatic: *f32,
    vignette: *f32,
    motion_blur: *f32,
    denoise: *f32,
    show_hud: *bool,
    show_console: *bool,
) void {
    fov.* = current.camera_fov;
    aperture.* = current.camera_aperture;
    focus_dist.* = current.camera_focus_dist;
    samples.* = current.samples_per_frame;
    bloom.* = current.bloom_strength;
    exposure.* = current.exposure;
    chromatic.* = current.chromatic_strength;
    vignette.* = current.vignette_strength;
    motion_blur.* = current.motion_blur_strength;
    denoise.* = current.denoise_strength;
    show_hud.* = current.show_hud;
    show_console.* = current.show_console;
}

// Capture current state from globals (call before save)
pub fn captureFromGlobals(
    fov: f32,
    aperture: f32,
    focus_dist: f32,
    samples: u32,
    bloom: f32,
    exposure: f32,
    chromatic: f32,
    vignette: f32,
    motion_blur: f32,
    denoise: f32,
    show_hud: bool,
    show_console: bool,
) void {
    current.camera_fov = fov;
    current.camera_aperture = aperture;
    current.camera_focus_dist = focus_dist;
    current.samples_per_frame = samples;
    current.bloom_strength = bloom;
    current.exposure = exposure;
    current.chromatic_strength = chromatic;
    current.vignette_strength = vignette;
    current.motion_blur_strength = motion_blur;
    current.denoise_strength = denoise;
    current.show_hud = show_hud;
    current.show_console = show_console;
}

pub fn addRecentFile(path: []const u8, allocator: std.mem.Allocator) !void {
    // Shift existing files down
    var i: usize = 9;
    while (i > 0) : (i -= 1) {
        if (current.recent_files[i - 1]) |old| {
            if (current.recent_files[i]) |existing| {
                allocator.free(existing);
            }
            current.recent_files[i] = old;
        }
    }
    // Add new file at top
    if (current.recent_files[0]) |existing| {
        allocator.free(existing);
    }
    current.recent_files[0] = try allocator.dupe(u8, path);
}
