const std = @import("std");

// ============================================================================
// EFFECTS MODULE - All post-processing and material effect parameters
// ============================================================================

// Camera and rendering
pub var camera_pos: @import("vec3.zig").Vec3 = @import("vec3.zig").Vec3.init(13, 2, 3);
pub var camera_yaw: f32 = 0;
pub var camera_pitch: f32 = -0.15;
pub var fov: f32 = 40.0;
pub var aperture: f32 = 0.02;
pub var focus_dist: f32 = 10.0;
pub var samples_per_frame: u32 = 4;

// Basic post-processing
pub var chromatic_strength: f32 = 0.0;
pub var motion_blur_strength: f32 = 0.0;
pub var bloom_strength: f32 = 0.15;
pub var exposure: f32 = 1.0;
pub var vignette_strength: f32 = 0.15;
pub var film_grain: f32 = 0.0;

// Material properties
pub var roughness_mult: f32 = 1.0;
pub var normal_strength: f32 = 1.0;
pub var displacement: f32 = 0.0;

// Advanced rendering
pub var nee_enabled: bool = true;
pub var denoise_strength: f32 = 0.0;
pub var fog_density: f32 = 0.0;
pub var fog_color: [3]f32 = .{ 0.5, 0.6, 0.7 };

// Lens effects
pub var bokeh_shape: i32 = 0; // 0=circle, 1=hexagon, 2=star, 3=heart
pub var dispersion: f32 = 0.0;
pub var lens_flare: f32 = 0.0;

// BATCH 1 EFFECTS
pub var iridescence: f32 = 0.0;
pub var anisotropy: f32 = 0.0;
pub var color_temp: f32 = 0.0;
pub var saturation: f32 = 1.0;
pub var scanlines: f32 = 0.0;
pub var tilt_shift: f32 = 0.0;
pub var glitter: f32 = 0.0;
pub var heat_haze: f32 = 0.0;

// BATCH 2 EFFECTS - MEGA FEATURES
pub var kaleidoscope: f32 = 0.0;
pub var pixelate: f32 = 0.0;
pub var edge_detect: f32 = 0.0;
pub var halftone: f32 = 0.0;
pub var night_vision: f32 = 0.0;
pub var thermal: f32 = 0.0;
pub var underwater: f32 = 0.0;
pub var rain_drops: f32 = 0.0;
pub var vhs_effect: f32 = 0.0;
pub var anaglyph_3d: f32 = 0.0;
pub var fisheye: f32 = 0.0;
pub var posterize: f32 = 0.0;
pub var sepia: f32 = 0.0;
pub var frosted: f32 = 0.0;
pub var radial_blur: f32 = 0.0;
pub var dither: f32 = 0.0;
pub var holographic: f32 = 0.0;
pub var ascii_mode: f32 = 0.0;

// UI state
pub var show_hud: bool = true;
pub var show_help: bool = false;
pub var save_screenshot: bool = false;

// Runtime state
pub var running: bool = true;
pub var mouse_captured: bool = false;
pub var mouse_dx: i32 = 0;
pub var mouse_dy: i32 = 0;
pub var keys: [256]bool = [_]bool{false} ** 256;

// Reset camera to default position
pub fn resetCamera() void {
    camera_pos = @import("vec3.zig").Vec3.init(13, 2, 3);
    camera_yaw = std.math.atan2(@as(f32, -3.0), @as(f32, -13.0));
    camera_pitch = -0.15;
}

// Reset all effects to defaults
pub fn resetEffects() void {
    chromatic_strength = 0.0;
    motion_blur_strength = 0.0;
    bloom_strength = 0.15;
    exposure = 1.0;
    vignette_strength = 0.15;
    film_grain = 0.0;
    roughness_mult = 1.0;
    normal_strength = 1.0;
    displacement = 0.0;
    denoise_strength = 0.0;
    fog_density = 0.0;
    dispersion = 0.0;
    lens_flare = 0.0;
    iridescence = 0.0;
    anisotropy = 0.0;
    color_temp = 0.0;
    saturation = 1.0;
    scanlines = 0.0;
    tilt_shift = 0.0;
    glitter = 0.0;
    heat_haze = 0.0;
    kaleidoscope = 0.0;
    pixelate = 0.0;
    edge_detect = 0.0;
    halftone = 0.0;
    night_vision = 0.0;
    thermal = 0.0;
    underwater = 0.0;
    rain_drops = 0.0;
    vhs_effect = 0.0;
    anaglyph_3d = 0.0;
    fisheye = 0.0;
    posterize = 0.0;
    sepia = 0.0;
    frosted = 0.0;
    radial_blur = 0.0;
    dither = 0.0;
    holographic = 0.0;
    ascii_mode = 0.0;
}
