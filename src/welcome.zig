const std = @import("std");

// ============================================================================
// WELCOME SCREEN - First-time user experience
// ============================================================================

pub const WelcomeState = enum {
    not_shown,
    showing,
    dismissed,
};

pub var state: WelcomeState = .not_shown;
pub var show_tips: bool = true;
pub var tip_index: usize = 0;

// Tips that rotate during idle
pub const tips = [_][]const u8{
    "Press TAB to toggle the HUD panel",
    "Press ~ (tilde) to open the debug console",
    "Right-click to toggle mouse look mode",
    "Use Ctrl+1 through Ctrl+5 to spawn different objects",
    "Hold Shift while pressing effect keys to decrease values",
    "Press P to toggle Flight Mode for 6DOF camera control",
    "In Flight Mode, use Q/E to roll the camera",
    "Press 1-4 to change render quality (samples per frame)",
    "Press R to reset camera position and all effects",
    "Press F12 to take a screenshot",
    "Use Ctrl+S to save your scene, Ctrl+O to load",
    "Press Del to remove the last spawned object",
    "Press 5-8 for debug visualizations (normals, depth, BVH)",
    "CSG objects (Ctrl+6-8) use ray marching for smooth shapes",
    "The console (~) shows profiler stats and object list",
    "Effects like Bloom, Vignette work great for cinematic looks",
    "Try the Thermal (F6) or Night Vision (F5) for fun effects",
    "Aperture (T/Y) and Focus (U/I) create depth of field blur",
};

pub const welcome_text =
    \\Welcome to Zig GPU Raytracer!
    \\
    \\A real-time path tracer built in Zig with OpenGL compute shaders.
    \\
    \\QUICK START:
    \\  - Right-click to enable mouse look
    \\  - WASD + Space/Ctrl to move
    \\  - Ctrl+1-5 to spawn objects
    \\  - TAB to toggle HUD
    \\  - ~ for debug console
    \\
    \\Press any key to continue...
;

pub fn show() void {
    state = .showing;
}

pub fn dismiss() void {
    state = .dismissed;
}

pub fn isShowing() bool {
    return state == .showing;
}

pub fn shouldShow() bool {
    return state == .not_shown;
}

pub fn getNextTip() []const u8 {
    const tip = tips[tip_index];
    tip_index = (tip_index + 1) % tips.len;
    return tip;
}

pub fn getCurrentTip() []const u8 {
    return tips[tip_index];
}

pub fn toggleTips() void {
    show_tips = !show_tips;
}

// Check if user has seen welcome before (via settings)
pub fn markAsSeen() void {
    state = .dismissed;
}

// Feature highlights for new users
pub const features = [_]struct { title: []const u8, description: []const u8 }{
    .{
        .title = "Real-time Path Tracing",
        .description = "GPU-accelerated ray tracing with progressive rendering",
    },
    .{
        .title = "5 Material Types",
        .description = "Diffuse, Metal, Glass, Emissive, and Subsurface Scattering",
    },
    .{
        .title = "40+ Post Effects",
        .description = "Bloom, DOF, Lens Flare, Night Vision, Thermal, and more",
    },
    .{
        .title = "Scene Management",
        .description = "Save/Load scenes as JSON, export images as PNG/BMP/HDR",
    },
    .{
        .title = "Debug Tools",
        .description = "BVH heatmap, normal visualization, depth view, profiler",
    },
    .{
        .title = "Demo Canvas Mode",
        .description = "Clean slate to experiment - spawn objects as you go",
    },
};

// Quick start guide sections
pub const quick_start = struct {
    pub const navigation =
        \\NAVIGATION:
        \\  WASD        Move around
        \\  Space/Ctrl  Up/Down
        \\  Mouse       Look (right-click to toggle)
        \\  Q/E         Roll (Flight mode only)
    ;

    pub const spawning =
        \\SPAWNING OBJECTS:
        \\  Ctrl+1  Diffuse sphere (matte)
        \\  Ctrl+2  Metal sphere (reflective)
        \\  Ctrl+3  Glass sphere (refractive)
        \\  Ctrl+4  Light source
        \\  Ctrl+5  SSS sphere (translucent)
        \\  Del     Remove last object
    ;

    pub const effects =
        \\EFFECTS (hold Shift to decrease):
        \\  B  Bloom        E  Exposure
        \\  V  Vignette     G  Film Grain
        \\  L  Lens Flare   C  Chromatic
        \\  M  Motion Blur  X  Heat Haze
    ;

    pub const files =
        \\FILE OPERATIONS:
        \\  Ctrl+N  New scene
        \\  Ctrl+O  Open scene
        \\  Ctrl+S  Save scene
        \\  Ctrl+E  Export PNG
        \\  F12     Screenshot
    ;
};
