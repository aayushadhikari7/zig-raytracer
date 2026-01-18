const std = @import("std");
const types = @import("types.zig");
const profiler = @import("profiler.zig");
const history = @import("history.zig");

const GPUSphere = types.GPUSphere;

// ============================================================================
// DOTA 2 STYLE DEMO HUD - Beautiful UI with CORRECT keybindings
// ============================================================================

const gl = @cImport({
    @cInclude("GL/gl.h");
});

// Simple 8x8 bitmap font
const font_data = [_]u64{
    0x0000000000000000, 0x1818181818001800, 0x6666660000000000, 0x6666FF66FF666600,
    0x183E603C067C1800, 0x6266180C18664600, 0x3C663C386F663B00, 0x1818300000000000,
    0x0C18303030180C00, 0x30180C0C0C183000, 0x00663CFF3C660000, 0x0018187E18180000,
    0x0000000000181830, 0x0000007E00000000, 0x0000000000181800, 0x03060C1830604000,
    0x3C666E7666663C00, 0x1838181818187E00, 0x3C66060C30607E00, 0x3C66061C06663C00,
    0x0C1C3C6C7E0C0C00, 0x7E607C0606663C00, 0x1C30607C66663C00, 0x7E06060C18181800,
    0x3C66663C66663C00, 0x3C66663E060C3800, 0x0000181800181800, 0x0000181800181830,
    0x0C18306030180C00, 0x00007E007E000000, 0x30180C060C183000, 0x3C66060C18001800,
    0x3C666E6A6E603C00, 0x183C66667E666600, 0x7C66667C66667C00, 0x3C66606060663C00,
    0x786C6666666C7800, 0x7E60607C60607E00, 0x7E60607C60606000, 0x3C66606E66663C00,
    0x6666667E66666600, 0x7E18181818187E00, 0x0606060606663C00, 0x666C7870786C6600,
    0x6060606060607E00, 0x63777F6B6B636300, 0x6676665E66666600, 0x3C66666666663C00,
    0x7C66667C60606000, 0x3C6666666A6C3600, 0x7C66667C6C666600, 0x3C66603C06663C00,
    0x7E18181818181800, 0x6666666666663C00, 0x66666666663C1800, 0x63636B6B7F776300,
    0x66663C183C666600, 0x6666663C18181800, 0x7E060C1830607E00, 0x3C30303030303C00,
    0x406030180C060200, 0x3C0C0C0C0C0C3C00, 0x183C664200000000, 0x00000000000000FF,
    0x1818180000000000, 0x00003C063E663E00, 0x60607C6666667C00, 0x00003C6060603C00,
    0x06063E6666663E00, 0x00003C667E603C00, 0x1C303C3030303000, 0x00003E66663E063C,
    0x60607C6666666600, 0x1800181818180C00, 0x0C000C0C0C0C0C38, 0x6060666C786C6600,
    0x1818181818180C00, 0x0000367F6B6B6300, 0x00007C6666666600, 0x00003C6666663C00,
    0x00007C66667C6060, 0x00003E66663E0606, 0x00007C6660606000, 0x00003E603C067C00,
    0x30307C3030301C00, 0x0000666666663E00, 0x00006666663C1800, 0x0000636B6B7F3600,
    0x0000663C183C6600, 0x00006666663E063C, 0x00007E0C18307E00, 0x0E18187018180E00,
    0x1818180018181800, 0x70180E0E18187000, 0x3B6E000000000000,
};

var font_texture: c_uint = 0;
var initialized: bool = false;

// Current tab (0=Spawn, 1=Effects, 2=Camera, 3=Debug)
pub var current_tab: u32 = 0;

pub fn init() void {
    if (initialized) return;

    var pixels: [96 * 8 * 8]u8 = undefined;
    for (0..96) |char_idx| {
        const char_data = font_data[char_idx];
        for (0..8) |row| {
            const row_bits: u8 = @truncate((char_data >> @intCast((7 - row) * 8)) & 0xFF);
            for (0..8) |col| {
                const pixel_idx = char_idx * 8 + row * 96 * 8 + col;
                const bit = (row_bits >> @intCast(7 - col)) & 1;
                pixels[pixel_idx] = if (bit == 1) 255 else 0;
            }
        }
    }

    gl.glGenTextures(1, &font_texture);
    gl.glBindTexture(gl.GL_TEXTURE_2D, font_texture);
    gl.glTexImage2D(gl.GL_TEXTURE_2D, 0, gl.GL_ALPHA, 96 * 8, 8, 0, gl.GL_ALPHA, gl.GL_UNSIGNED_BYTE, &pixels);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MIN_FILTER, gl.GL_NEAREST);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MAG_FILTER, gl.GL_NEAREST);
    initialized = true;
}

fn drawChar(x: f32, y: f32, char: u8, scale: f32) void {
    if (char < 32 or char > 126) return;
    const char_idx: f32 = @floatFromInt(char - 32);
    const tex_x = char_idx * 8.0 / (96.0 * 8.0);
    const tex_w = 8.0 / (96.0 * 8.0);
    gl.glTexCoord2f(tex_x, 0); gl.glVertex2f(x, y);
    gl.glTexCoord2f(tex_x + tex_w, 0); gl.glVertex2f(x + 8.0 * scale, y);
    gl.glTexCoord2f(tex_x + tex_w, 1); gl.glVertex2f(x + 8.0 * scale, y + 8.0 * scale);
    gl.glTexCoord2f(tex_x, 1); gl.glVertex2f(x, y + 8.0 * scale);
}

fn drawText(x: f32, y: f32, str: []const u8, scale: f32) void {
    var px = x;
    for (str) |char| { drawChar(px, y, char, scale); px += 8.0 * scale; }
}

fn text(x: f32, y: f32, txt: []const u8, scale: f32, r: f32, g: f32, b: f32) void {
    gl.glColor4f(r, g, b, 1.0);
    gl.glBegin(gl.GL_QUADS);
    drawText(x, y, txt, scale);
    gl.glEnd();
}

fn rect(x: f32, y: f32, w: f32, h: f32, r: f32, g: f32, b: f32, a: f32) void {
    gl.glDisable(gl.GL_TEXTURE_2D);
    gl.glColor4f(r, g, b, a);
    gl.glBegin(gl.GL_QUADS);
    gl.glVertex2f(x, y); gl.glVertex2f(x + w, y);
    gl.glVertex2f(x + w, y + h); gl.glVertex2f(x, y + h);
    gl.glEnd();
    gl.glEnable(gl.GL_TEXTURE_2D);
}

fn gradRect(x: f32, y: f32, w: f32, h: f32, r1: f32, g1: f32, b1: f32, r2: f32, g2: f32, b2: f32, a: f32) void {
    gl.glDisable(gl.GL_TEXTURE_2D);
    gl.glBegin(gl.GL_QUADS);
    gl.glColor4f(r1, g1, b1, a); gl.glVertex2f(x, y); gl.glVertex2f(x + w, y);
    gl.glColor4f(r2, g2, b2, a); gl.glVertex2f(x + w, y + h); gl.glVertex2f(x, y + h);
    gl.glEnd();
    gl.glEnable(gl.GL_TEXTURE_2D);
}

fn floatStr(buf: []u8, v: f32) []const u8 {
    return std.fmt.bufPrint(buf, "{d:.2}", .{v}) catch "?";
}

// ============================================================================
// MAIN RENDER
// ============================================================================

pub fn render(width: i32, height: i32, effects: anytype, show_hud: bool, show_console: bool, spheres: []const GPUSphere, fps: f32) void {
    if (!initialized) init();

    // Render console if enabled (takes priority)
    if (show_console) {
        renderConsole(width, height, spheres, fps, effects);
        return;
    }

    if (!show_hud) return;

    const w: f32 = @floatFromInt(width);
    const h: f32 = @floatFromInt(height);

    gl.glMatrixMode(gl.GL_PROJECTION);
    gl.glPushMatrix();
    gl.glLoadIdentity();
    gl.glOrtho(0, @floatFromInt(width), @floatFromInt(height), 0, -1, 1);
    gl.glMatrixMode(gl.GL_MODELVIEW);
    gl.glPushMatrix();
    gl.glLoadIdentity();
    gl.glEnable(gl.GL_BLEND);
    gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA);
    gl.glEnable(gl.GL_TEXTURE_2D);
    gl.glBindTexture(gl.GL_TEXTURE_2D, font_texture);

    // ========== TOP BAR ==========
    gradRect(0, 0, w, 45, 0.08, 0.08, 0.12, 0.04, 0.04, 0.07, 0.95);
    rect(0, 43, w, 2, 0.2, 0.6, 1.0, 0.8);
    text(20, 12, "RAYTRACER DEMO", 2.2, 0.9, 0.95, 1.0);

    // Tabs
    const tabs = [_][]const u8{ "SPAWN", "EFFECTS", "CAMERA", "DEBUG", "SETTINGS" };
    const tab_w: f32 = 85;
    var tx: f32 = w - 440;
    for (tabs, 0..) |name, i| {
        const active = current_tab == i;
        if (active) {
            rect(tx, 8, tab_w - 5, 28, 0.2, 0.5, 0.9, 0.9);
            text(tx + 10, 14, name, 1.4, 1.0, 1.0, 1.0);
        } else {
            rect(tx, 8, tab_w - 5, 28, 0.12, 0.12, 0.18, 0.7);
            text(tx + 10, 14, name, 1.4, 0.5, 0.5, 0.6);
        }
        tx += tab_w;
    }

    // ========== LEFT PANEL ==========
    const px: f32 = 15;
    const py: f32 = 55;
    const pw: f32 = 360;
    const ph: f32 = h - 100;
    gradRect(px, py, pw, ph, 0.05, 0.05, 0.08, 0.02, 0.02, 0.05, 0.9);

    var buf: [64]u8 = undefined;
    const s: f32 = 1.4;
    const lh: f32 = 18;
    var y: f32 = py + 15;
    const x: f32 = px + 15;

    switch (current_tab) {
        0 => { // SPAWN TAB
            text(x, y, "SPAWN OBJECTS (Ctrl+Key)", s * 1.1, 0.3, 0.8, 1.0); y += lh * 1.5;

            text(x, y, "SPHERES", s, 0.9, 0.7, 0.3); y += lh;
            const sphere_cmds = [_][2][]const u8{
                .{ "Ctrl+1", "Diffuse Sphere" },
                .{ "Ctrl+2", "Metal Sphere" },
                .{ "Ctrl+3", "Glass Sphere" },
                .{ "Ctrl+4", "Light Sphere" },
                .{ "Ctrl+5", "SSS Sphere" },
            };
            for (sphere_cmds) |sp| {
                text(x + 10, y, sp[0], s, 0.5, 0.7, 0.9);
                text(x + 100, y, sp[1], s, 0.7, 0.7, 0.7);
                y += lh;
            }

            y += lh * 0.5;
            text(x, y, "MESHES", s, 0.9, 0.7, 0.3); y += lh;
            text(x + 10, y, "Ctrl+0", s, 0.5, 0.7, 0.9);
            text(x + 100, y, "Load OBJ File", s, 0.7, 0.7, 0.7); y += lh * 1.5;

            y += lh * 0.5;
            text(x, y, "OTHER", s, 0.9, 0.7, 0.3); y += lh;
            text(x + 10, y, "Del", s, 0.5, 0.7, 0.9);
            text(x + 100, y, "Remove last object", s, 0.7, 0.7, 0.7); y += lh;
            text(x + 10, y, "R", s, 0.5, 0.7, 0.9);
            text(x + 100, y, "Reset scene", s, 0.7, 0.7, 0.7); y += lh * 1.5;

            rect(x - 5, y, pw - 20, 25, 0.1, 0.15, 0.2, 0.7);
            text(x + 5, y + 5, "Objects spawn in front of camera", s * 0.9, 0.6, 0.8, 0.6);
        },
        1 => { // EFFECTS TAB
            text(x, y, "POST-PROCESSING EFFECTS", s * 1.1, 0.3, 0.8, 1.0); y += lh * 1.5;
            text(x, y, "Key = increase, Shift+Key = decrease", s * 0.85, 0.5, 0.8, 0.5); y += lh * 1.2;

            // Effects with keyboard shortcuts
            const efx = [_]struct { n: []const u8, k: []const u8, v: f32, m: f32 }{
                .{ .n = "Bloom", .k = "B", .v = effects.bloom_strength, .m = 1.0 },
                .{ .n = "Exposure", .k = "X", .v = effects.exposure, .m = 5.0 },
                .{ .n = "Chromatic", .k = "C", .v = effects.chromatic_strength, .m = 0.02 },
                .{ .n = "Vignette", .k = "V", .v = effects.vignette_strength, .m = 0.5 },
                .{ .n = "MotionBlur", .k = "M", .v = effects.motion_blur, .m = 2.0 },
                .{ .n = "FilmGrain", .k = "N", .v = effects.film_grain, .m = 1.0 },
                .{ .n = "Denoise", .k = "J", .v = effects.denoise_strength, .m = 2.0 },
            };
            for (efx) |e| {
                // Key hint
                text(x, y, e.k, s, 0.5, 0.7, 0.9);
                // Effect name
                text(x + 20, y, e.n, s * 0.95, 0.7, 0.7, 0.7);
                // Slider bar background
                const bar_x = x + 115;
                rect(bar_x, y + 2, 100, 12, 0.15, 0.15, 0.2, 0.8);
                // Slider fill
                const fill = 100 * @min(e.v / e.m, 1.0);
                if (fill > 0) rect(bar_x, y + 2, fill, 12, 0.3, 0.7, 0.9, 0.9);
                // Slider handle
                const handle_x = bar_x + fill - 3;
                rect(handle_x, y, 6, 16, 0.9, 0.9, 0.9, 0.9);
                // Value text
                text(bar_x + 110, y, floatStr(&buf, e.v), s * 0.9, 0.5, 0.8, 0.5);
                y += lh * 1.1;
            }

            y += lh * 0.8;
            rect(x - 5, y, pw - 20, 50, 0.08, 0.12, 0.18, 0.7);
            text(x + 5, y + 5, "Or drag sliders with mouse", s * 0.85, 0.5, 0.7, 0.5);
            text(x + 5, y + 20, "R = Reset ALL effects", s * 0.85, 0.5, 0.7, 0.5);
            text(x + 5, y + 35, "+/- keys = Exposure (global)", s * 0.85, 0.4, 0.8, 0.4);
        },
        2 => { // CAMERA TAB
            text(x, y, "CAMERA CONTROLS", s * 1.1, 0.3, 0.8, 1.0); y += lh * 1.5;

            const mode = if (effects.flight_mode) "FLIGHT MODE (6DOF)" else "FPS MODE";
            rect(x, y, 220, 22, if (effects.flight_mode) 0.2 else 0.1, if (effects.flight_mode) 0.4 else 0.15, if (effects.flight_mode) 0.3 else 0.2, 0.8);
            text(x + 10, y + 4, mode, s, 0.9, 0.9, 0.9);
            text(x + 230, y + 4, "P to toggle", s * 0.9, 0.5, 0.7, 0.9);
            y += lh * 1.8;

            text(x, y, "MOVEMENT", s, 0.9, 0.7, 0.3); y += lh;
            const mov = [_][2][]const u8{
                .{ "W/S", "Forward / Back" },
                .{ "A/D", "Strafe Left / Right" },
                .{ "Space", "Move Up" },
                .{ "Ctrl", "Move Down (HUD closed)" },
                .{ "Q/E", "Roll (Flight mode)" },
                .{ "RClick", "Toggle Mouse Look" },
                .{ "R", "Reset Camera & Effects" },
            };
            for (mov) |m| {
                text(x + 10, y, m[0], s * 0.95, 0.5, 0.7, 0.9);
                text(x + 80, y, m[1], s * 0.95, 0.6, 0.6, 0.7);
                y += lh * 0.9;
            }

            y += lh * 0.5;
            text(x, y, "LENS (Camera tab keybinds)", s, 0.9, 0.7, 0.3); y += lh;
            const lens = [_]struct { n: []const u8, k: []const u8, v: f32, g: bool }{
                .{ .n = "FOV", .k = "F/G", .v = effects.fov, .g = true },
                .{ .n = "Aperture (DOF)", .k = "T/Y", .v = effects.aperture, .g = false },
                .{ .n = "Focus Distance", .k = "U/I", .v = effects.focus_dist, .g = false },
            };
            for (lens) |l| {
                text(x + 10, y, l.k, s, 0.5, 0.7, 0.9);
                text(x + 50, y, l.n, s, 0.6, 0.6, 0.7);
                text(x + 180, y, floatStr(&buf, l.v), s, 0.5, 0.9, 0.5);
                if (l.g) text(x + 240, y, "(global)", s * 0.8, 0.4, 0.6, 0.4);
                y += lh;
            }
        },
        3 => { // DEBUG TAB - Quality & Debug modes
            text(x, y, "DEBUG & QUALITY", s * 1.1, 0.3, 0.8, 1.0); y += lh * 1.5;

            text(x, y, "QUALITY PRESETS (this tab)", s, 0.9, 0.7, 0.3); y += lh;
            const quality_keys = [_]struct { k: []const u8, n: []const u8, samples: u32 }{
                .{ .k = "1", .n = "2 samples (fast)", .samples = 2 },
                .{ .k = "2", .n = "4 samples", .samples = 4 },
                .{ .k = "3", .n = "8 samples", .samples = 8 },
                .{ .k = "4", .n = "16 samples (slow)", .samples = 16 },
            };
            for (quality_keys) |q| {
                const active = effects.samples_per_frame == q.samples;
                if (active) rect(x + 5, y - 2, pw - 30, lh, 0.2, 0.5, 0.3, 0.4);
                text(x + 10, y, q.k, s * 0.95, 0.5, 0.7, 0.9);
                text(x + 40, y, q.n, s * 0.95, if (active) 0.9 else 0.6, if (active) 0.9 else 0.6, if (active) 0.9 else 0.7);
                y += lh * 0.9;
            }

            y += lh * 0.5;
            text(x, y, "DEBUG MODES (this tab)", s, 0.9, 0.7, 0.3); y += lh;
            const dbg = [_]struct { n: []const u8, k: []const u8, i: u32 }{
                .{ .n = "Normal render", .k = "5", .i = 0 },
                .{ .n = "BVH Heatmap", .k = "6", .i = 1 },
                .{ .n = "Normals", .k = "7", .i = 2 },
                .{ .n = "Depth", .k = "8", .i = 3 },
            };
            for (dbg) |d| {
                const active = effects.debug_mode == d.i;
                if (active) rect(x + 5, y - 2, pw - 30, lh, 0.2, 0.4, 0.6, 0.4);
                text(x + 10, y, d.k, s * 0.95, 0.5, 0.7, 0.9);
                text(x + 40, y, d.n, s * 0.95, if (active) 0.9 else 0.6, if (active) 0.9 else 0.6, if (active) 0.9 else 0.7);
                y += lh * 0.9;
            }

            y += lh * 0.5;
            text(x, y, "GLOBAL SHORTCUTS", s, 0.9, 0.7, 0.3); y += lh;
            const global_keys = [_][2][]const u8{
                .{ "F/G", "FOV adjust" },
                .{ "+/-", "Exposure adjust" },
                .{ "TAB", "Toggle HUD" },
                .{ "~", "Toggle console" },
                .{ "F12", "Screenshot" },
                .{ "Del", "Remove last object" },
                .{ "R", "Reset camera & effects" },
                .{ "ESC", "Exit" },
            };
            for (global_keys) |k| {
                text(x + 10, y, k[0], s * 0.95, 0.4, 0.9, 0.4);
                text(x + 60, y, k[1], s * 0.95, 0.6, 0.6, 0.7);
                y += lh * 0.9;
            }
        },
        4 => { // SETTINGS TAB
            text(x, y, "SETTINGS", s * 1.1, 0.3, 0.8, 1.0); y += lh * 1.5;

            // Resolution presets - clickable buttons
            text(x, y, "RESOLUTION (click to change)", s, 0.9, 0.7, 0.3); y += lh;
            const res_opts = [_]struct { n: []const u8, w: u32, h: u32 }{
                .{ .n = "720p", .w = 1280, .h = 720 },
                .{ .n = "1080p", .w = 1920, .h = 1080 },
                .{ .n = "1440p", .w = 2560, .h = 1440 },
                .{ .n = "4K", .w = 3840, .h = 2160 },
            };
            var rx: f32 = x;
            for (res_opts) |r| {
                const active = (effects.render_width == r.w and effects.render_height == r.h);
                const btn_w: f32 = 70;
                if (active) {
                    rect(rx, y, btn_w, 20, 0.5, 0.3, 0.2, 0.9);
                } else {
                    rect(rx, y, btn_w, 20, 0.15, 0.15, 0.2, 0.8);
                }
                text(rx + 8, y + 4, r.n, s * 0.9, if (active) 1.0 else 0.6, if (active) 1.0 else 0.6, if (active) 1.0 else 0.7);
                rx += btn_w + 5;
            }
            y += lh * 1.8;

            // Quality presets - clickable buttons
            text(x, y, "QUALITY PRESET (click to select)", s, 0.9, 0.7, 0.3); y += lh;
            const quality_opts = [_]struct { n: []const u8, samples: u32 }{
                .{ .n = "Fast", .samples = 2 },
                .{ .n = "Medium", .samples = 4 },
                .{ .n = "High", .samples = 8 },
                .{ .n = "Ultra", .samples = 16 },
            };
            var qx: f32 = x;
            for (quality_opts) |q| {
                const active = effects.samples_per_frame == q.samples;
                const btn_w: f32 = 70;
                if (active) {
                    rect(qx, y, btn_w, 20, 0.2, 0.5, 0.3, 0.9);
                } else {
                    rect(qx, y, btn_w, 20, 0.15, 0.15, 0.2, 0.8);
                }
                text(qx + 5, y + 4, q.n, s * 0.9, if (active) 1.0 else 0.6, if (active) 1.0 else 0.6, if (active) 1.0 else 0.7);
                qx += btn_w + 5;
            }
            y += lh * 1.8;

            // Debug mode buttons
            text(x, y, "RENDER MODE (click to select)", s, 0.9, 0.7, 0.3); y += lh;
            const debug_opts = [_]struct { n: []const u8, mode: u32 }{
                .{ .n = "Normal", .mode = 0 },
                .{ .n = "BVH", .mode = 1 },
                .{ .n = "Normals", .mode = 2 },
                .{ .n = "Depth", .mode = 3 },
            };
            var dx: f32 = x;
            for (debug_opts) |d| {
                const active = effects.debug_mode == d.mode;
                const btn_w: f32 = 70;
                if (active) {
                    rect(dx, y, btn_w, 20, 0.2, 0.4, 0.6, 0.9);
                } else {
                    rect(dx, y, btn_w, 20, 0.15, 0.15, 0.2, 0.8);
                }
                text(dx + 5, y + 4, d.n, s * 0.9, if (active) 1.0 else 0.6, if (active) 1.0 else 0.6, if (active) 1.0 else 0.7);
                dx += btn_w + 5;
            }
            y += lh * 1.8;

            // Camera info
            text(x, y, "CAMERA", s, 0.9, 0.7, 0.3); y += lh;
            const fov_str = std.fmt.bufPrint(&buf, "FOV: {d:.0}  (F/G to adjust)", .{effects.fov}) catch "?";
            text(x + 10, y, fov_str, s * 0.9, 0.6, 0.8, 0.6); y += lh;
            const ap_str = std.fmt.bufPrint(&buf, "Aperture: {d:.3}  Focus: {d:.1}", .{ effects.aperture, effects.focus_dist }) catch "?";
            text(x + 10, y, ap_str, s * 0.9, 0.6, 0.6, 0.7); y += lh;
            const mode_str = if (effects.flight_mode) "Flight Mode ON" else "FPS Mode";
            text(x + 10, y, mode_str, s * 0.9, 0.5, 0.7, 0.9); y += lh * 1.5;

            // Effects summary
            text(x, y, "EFFECTS SUMMARY", s, 0.9, 0.7, 0.3); y += lh;
            const exp_str = std.fmt.bufPrint(&buf, "Exposure: {d:.2}  (+/- to adjust)", .{effects.exposure}) catch "?";
            text(x + 10, y, exp_str, s * 0.9, 0.6, 0.8, 0.6); y += lh;
            const fx_str = std.fmt.bufPrint(&buf, "Bloom:{d:.2} Vign:{d:.2} Denoise:{d:.1}", .{ effects.bloom_strength, effects.vignette_strength, effects.denoise_strength }) catch "?";
            text(x + 10, y, fx_str, s * 0.85, 0.5, 0.6, 0.7); y += lh * 1.5;

            // Action buttons
            text(x, y, "ACTIONS", s, 0.9, 0.7, 0.3); y += lh;
            // Reset button
            rect(x, y, 100, 22, 0.6, 0.2, 0.2, 0.9);
            text(x + 10, y + 4, "R - RESET ALL", s * 0.9, 1.0, 1.0, 1.0);
            // Screenshot button
            rect(x + 110, y, 110, 22, 0.2, 0.4, 0.6, 0.9);
            text(x + 120, y + 4, "F12 - SCREENSHOT", s * 0.8, 1.0, 1.0, 1.0);
            y += lh * 1.8;

            rect(x - 5, y, pw - 20, 25, 0.08, 0.12, 0.18, 0.7);
            text(x + 5, y + 6, "Settings auto-save on exit", s * 0.85, 0.5, 0.7, 0.5);
        },
        else => {},
    }

    // ========== BOTTOM BAR ==========
    gradRect(0, h - 32, w, 32, 0.04, 0.04, 0.07, 0.07, 0.07, 0.1, 0.9);
    text(20, h - 22, "WASD:Move | 1-4:Quality | 5-8:Debug | Ctrl+1-5:Spawn | TAB:HUD | ~:Console | Click tabs above", 1.2, 0.4, 0.4, 0.5);

    gl.glDisable(gl.GL_BLEND);
    gl.glDisable(gl.GL_TEXTURE_2D);
    gl.glMatrixMode(gl.GL_PROJECTION);
    gl.glPopMatrix();
    gl.glMatrixMode(gl.GL_MODELVIEW);
    gl.glPopMatrix();
}

// Tab switching with number keys when HUD is visible
pub fn handleTabSwitch(key: u8) bool {
    if (key >= '1' and key <= '4') { current_tab = key - '1'; return true; }
    return false;
}

// ============================================================================
// DEBUG CONSOLE - Shows all scene objects (Press ~ to toggle)
// ============================================================================

fn renderConsole(width: i32, height: i32, spheres: []const GPUSphere, fps: f32, effects: anytype) void {
    const w: f32 = @floatFromInt(width);
    const h: f32 = @floatFromInt(height);

    gl.glMatrixMode(gl.GL_PROJECTION);
    gl.glPushMatrix();
    gl.glLoadIdentity();
    gl.glOrtho(0, @floatFromInt(width), @floatFromInt(height), 0, -1, 1);
    gl.glMatrixMode(gl.GL_MODELVIEW);
    gl.glPushMatrix();
    gl.glLoadIdentity();
    gl.glEnable(gl.GL_BLEND);
    gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA);
    gl.glEnable(gl.GL_TEXTURE_2D);
    gl.glBindTexture(gl.GL_TEXTURE_2D, font_texture);

    // Full-screen dark background
    rect(0, 0, w, h, 0.02, 0.02, 0.05, 0.95);

    // Header bar
    gradRect(0, 0, w, 50, 0.1, 0.15, 0.25, 0.05, 0.08, 0.12, 1.0);
    rect(0, 48, w, 2, 0.3, 0.6, 1.0, 0.9);
    text(20, 15, "SCENE CONSOLE", 2.5, 0.4, 0.8, 1.0);
    text(w - 200, 18, "Press ~ to close", 1.4, 0.5, 0.5, 0.6);

    var buf: [128]u8 = undefined;
    const s: f32 = 1.3;
    const lh: f32 = 16;
    var y: f32 = 70;
    const x: f32 = 30;

    // FPS and stats header
    rect(x - 10, y - 5, 400, 50, 0.08, 0.12, 0.18, 0.8);
    const fps_str = std.fmt.bufPrint(&buf, "FPS: {d:.1}  |  Objects: {}  |  SPF: {}", .{ fps, spheres.len, effects.samples_per_frame }) catch "?";
    text(x, y, fps_str, s * 1.2, 0.3, 0.9, 0.4);
    y += lh * 1.2;
    const mode_str = if (effects.flight_mode) "Flight Mode (6DOF)" else "FPS Mode";
    text(x, y, mode_str, s, 0.6, 0.6, 0.7);
    y += lh * 2;

    // Two column layout
    const col1_x: f32 = x;
    const col2_x: f32 = w / 2 + 20;

    // Column 1: Scene Objects
    var col1_y = y;
    rect(col1_x - 10, col1_y - 5, w / 2 - 50, h - col1_y - 60, 0.04, 0.05, 0.08, 0.7);
    text(col1_x, col1_y, "SCENE OBJECTS", s * 1.3, 0.9, 0.7, 0.3);
    col1_y += lh * 1.8;

    // Material type names
    const mat_names = [_][]const u8{ "Diffuse", "Metal", "Glass", "Emissive", "SSS" };
    const mat_colors = [_][3]f32{
        .{ 0.7, 0.7, 0.7 }, // Diffuse - gray
        .{ 0.9, 0.8, 0.5 }, // Metal - gold
        .{ 0.5, 0.8, 1.0 }, // Glass - cyan
        .{ 1.0, 0.9, 0.4 }, // Emissive - yellow
        .{ 0.6, 0.9, 0.6 }, // SSS - green
    };

    // Show spheres (max 20 to fit on screen)
    const max_display = @min(spheres.len, 20);
    for (0..max_display) |i| {
        const sphere = spheres[i];
        const mat_idx: usize = @intCast(@max(0, @min(4, sphere.mat_type)));
        const mat_name = mat_names[mat_idx];
        const color = mat_colors[mat_idx];

        // Object index
        const idx_str = std.fmt.bufPrint(&buf, "[{}]", .{i}) catch "?";
        text(col1_x, col1_y, idx_str, s * 0.9, 0.4, 0.5, 0.6);

        // Material type
        text(col1_x + 40, col1_y, mat_name, s, color[0], color[1], color[2]);

        // Position
        var pos_buf: [64]u8 = undefined;
        const pos_str = std.fmt.bufPrint(&pos_buf, "({d:.1}, {d:.1}, {d:.1})", .{ sphere.center[0], sphere.center[1], sphere.center[2] }) catch "?";
        text(col1_x + 140, col1_y, pos_str, s * 0.9, 0.5, 0.5, 0.6);

        // Radius
        var rad_buf: [32]u8 = undefined;
        const rad_str = std.fmt.bufPrint(&rad_buf, "r={d:.2}", .{sphere.radius}) catch "?";
        text(col1_x + 330, col1_y, rad_str, s * 0.9, 0.5, 0.6, 0.5);

        col1_y += lh;
    }

    if (spheres.len > 20) {
        var more_buf: [32]u8 = undefined;
        const more_str = std.fmt.bufPrint(&more_buf, "... and {} more", .{spheres.len - 20}) catch "?";
        text(col1_x, col1_y, more_str, s * 0.9, 0.5, 0.5, 0.6);
    }

    // Column 2: Active Effects
    var col2_y = y;
    rect(col2_x - 10, col2_y - 5, w / 2 - 50, h - col2_y - 60, 0.04, 0.05, 0.08, 0.7);
    text(col2_x, col2_y, "ACTIVE EFFECTS", s * 1.3, 0.9, 0.7, 0.3);
    col2_y += lh * 1.8;

    // List all non-zero effects
    const effect_list = [_]struct { name: []const u8, value: f32 }{
        .{ .name = "Bloom", .value = effects.bloom_strength },
        .{ .name = "Exposure", .value = effects.exposure },
        .{ .name = "Chromatic Aberration", .value = effects.chromatic_strength },
        .{ .name = "Vignette", .value = effects.vignette_strength },
        .{ .name = "Motion Blur", .value = effects.motion_blur },
        .{ .name = "Film Grain", .value = effects.film_grain },
        .{ .name = "Lens Flare", .value = effects.lens_flare },
        .{ .name = "Heat Haze", .value = effects.heat_haze },
        .{ .name = "Scanlines", .value = effects.scanlines },
        .{ .name = "Tilt Shift", .value = effects.tilt_shift },
        .{ .name = "Sepia", .value = effects.sepia },
        .{ .name = "Dither", .value = effects.dither },
        .{ .name = "Night Vision", .value = effects.night_vision },
        .{ .name = "Thermal", .value = effects.thermal },
        .{ .name = "Underwater", .value = effects.underwater },
        .{ .name = "Fisheye", .value = effects.fisheye },
        .{ .name = "Kaleidoscope", .value = effects.kaleidoscope },
        .{ .name = "Pixelate", .value = effects.pixelate },
        .{ .name = "Halftone", .value = effects.halftone },
        .{ .name = "Edge Detect", .value = effects.edge_detect },
        .{ .name = "VHS Effect", .value = effects.vhs_effect },
        .{ .name = "3D Anaglyph", .value = effects.anaglyph_3d },
    };

    for (effect_list) |e| {
        if (e.value > 0.001) {
            // Effect name
            text(col2_x, col2_y, e.name, s, 0.7, 0.7, 0.7);
            // Value bar
            const bar_x = col2_x + 180;
            rect(bar_x, col2_y + 2, 100, 10, 0.15, 0.15, 0.2, 0.8);
            const fill = 100 * @min(e.value, 1.0);
            rect(bar_x, col2_y + 2, fill, 10, 0.3, 0.7, 0.9, 0.9);
            // Value text
            text(bar_x + 110, col2_y, floatStr(&buf, e.value), s * 0.9, 0.5, 0.8, 0.5);
            col2_y += lh;
        }
    }

    if (col2_y == y + lh * 1.8) {
        text(col2_x, col2_y, "No post-effects active", s, 0.5, 0.5, 0.5);
    }

    // Camera info section
    col2_y += lh * 1.5;
    text(col2_x, col2_y, "CAMERA", s * 1.3, 0.9, 0.7, 0.3);
    col2_y += lh * 1.5;
    text(col2_x, col2_y, std.fmt.bufPrint(&buf, "FOV: {d:.0}", .{effects.fov}) catch "?", s, 0.6, 0.6, 0.7);
    col2_y += lh;
    text(col2_x, col2_y, std.fmt.bufPrint(&buf, "Aperture: {d:.3}", .{effects.aperture}) catch "?", s, 0.6, 0.6, 0.7);
    col2_y += lh;
    text(col2_x, col2_y, std.fmt.bufPrint(&buf, "Focus Dist: {d:.1}", .{effects.focus_dist}) catch "?", s, 0.6, 0.6, 0.7);
    col2_y += lh;
    if (effects.flight_mode) {
        text(col2_x, col2_y, std.fmt.bufPrint(&buf, "Roll: {d:.2} rad", .{effects.camera_roll}) catch "?", s, 0.6, 0.6, 0.7);
        col2_y += lh;
    }

    // Profiler section
    col2_y += lh * 0.5;
    text(col2_x, col2_y, "PROFILER", s * 1.3, 0.9, 0.7, 0.3);
    col2_y += lh * 1.5;

    const prof = &profiler.global;
    text(col2_x, col2_y, std.fmt.bufPrint(&buf, "Frame: {d:.2}ms", .{prof.getSectionTime(.frame_total)}) catch "?", s, 0.6, 0.6, 0.7);
    col2_y += lh;
    text(col2_x, col2_y, std.fmt.bufPrint(&buf, "Avg FPS: {d:.1}", .{prof.getRecentAverageFPS()}) catch "?", s, 0.5, 0.9, 0.5);
    col2_y += lh;
    text(col2_x, col2_y, std.fmt.bufPrint(&buf, "Ray Gen: {d:.2}ms", .{prof.getSectionTime(.ray_generation)}) catch "?", s, 0.6, 0.6, 0.7);
    col2_y += lh;
    text(col2_x, col2_y, std.fmt.bufPrint(&buf, "Post-Proc: {d:.2}ms", .{prof.getSectionTime(.post_processing)}) catch "?", s, 0.6, 0.6, 0.7);
    col2_y += lh;
    text(col2_x, col2_y, std.fmt.bufPrint(&buf, "HUD: {d:.2}ms", .{prof.getSectionTime(.hud_render)}) catch "?", s, 0.6, 0.6, 0.7);
    col2_y += lh;
    text(col2_x, col2_y, std.fmt.bufPrint(&buf, "Samples: {}", .{prof.samples_accumulated}) catch "?", s, 0.6, 0.6, 0.7);
    col2_y += lh;
    const rays_m = prof.rays_per_frame / 1_000_000;
    text(col2_x, col2_y, std.fmt.bufPrint(&buf, "Rays/frame: {}M", .{rays_m}) catch "?", s, 0.6, 0.6, 0.7);
    col2_y += lh;
    // History info
    const can_undo = history.canUndo();
    const can_redo = history.canRedo();
    text(col2_x, col2_y, std.fmt.bufPrint(&buf, "History: {} actions", .{history.getCount()}) catch "?", s, 0.6, 0.6, 0.7);
    col2_y += lh;
    text(col2_x, col2_y, std.fmt.bufPrint(&buf, "Undo: {s} Redo: {s}", .{
        if (can_undo) @as([]const u8, "Yes") else @as([]const u8, "No"),
        if (can_redo) @as([]const u8, "Yes") else @as([]const u8, "No"),
    }) catch "?", s, if (can_undo) 0.5 else 0.4, 0.9, if (can_redo) 0.5 else 0.4);

    // Bottom bar with controls
    gradRect(0, h - 40, w, 40, 0.05, 0.08, 0.12, 0.08, 0.1, 0.15, 0.95);
    text(20, h - 28, "~ Close | TAB HUD | WASD Move | Ctrl+Z Undo | Ctrl+Y Redo | F12 Screenshot | ESC Exit", 1.2, 0.4, 0.5, 0.6);

    gl.glDisable(gl.GL_BLEND);
    gl.glDisable(gl.GL_TEXTURE_2D);
    gl.glMatrixMode(gl.GL_PROJECTION);
    gl.glPopMatrix();
    gl.glMatrixMode(gl.GL_MODELVIEW);
    gl.glPopMatrix();
}
