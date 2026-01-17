const std = @import("std");

// ============================================================================
// HUD MODULE - On-screen control overlay
// ============================================================================

const gl = @cImport({
    @cInclude("GL/gl.h");
});

// Simple 8x8 bitmap font (ASCII 32-127)
// Each character is 8 bytes, one byte per row, MSB = leftmost pixel
const font_data = [_]u64{
    0x0000000000000000, // 32 ' '
    0x1818181818001800, // 33 '!'
    0x6666660000000000, // 34 '"'
    0x6666FF66FF666600, // 35 '#'
    0x183E603C067C1800, // 36 '$'
    0x6266180C18664600, // 37 '%'
    0x3C663C386F663B00, // 38 '&'
    0x1818300000000000, // 39 '''
    0x0C18303030180C00, // 40 '('
    0x30180C0C0C183000, // 41 ')'
    0x00663CFF3C660000, // 42 '*'
    0x0018187E18180000, // 43 '+'
    0x0000000000181830, // 44 ','
    0x0000007E00000000, // 45 '-'
    0x0000000000181800, // 46 '.'
    0x03060C1830604000, // 47 '/'
    0x3C666E7666663C00, // 48 '0'
    0x1838181818187E00, // 49 '1'
    0x3C66060C30607E00, // 50 '2'
    0x3C66061C06663C00, // 51 '3'
    0x0C1C3C6C7E0C0C00, // 52 '4'
    0x7E607C0606663C00, // 53 '5'
    0x1C30607C66663C00, // 54 '6'
    0x7E06060C18181800, // 55 '7'
    0x3C66663C66663C00, // 56 '8'
    0x3C66663E060C3800, // 57 '9'
    0x0000181800181800, // 58 ':'
    0x0000181800181830, // 59 ';'
    0x0C18306030180C00, // 60 '<'
    0x00007E007E000000, // 61 '='
    0x30180C060C183000, // 62 '>'
    0x3C66060C18001800, // 63 '?'
    0x3C666E6A6E603C00, // 64 '@'
    0x183C66667E666600, // 65 'A'
    0x7C66667C66667C00, // 66 'B'
    0x3C66606060663C00, // 67 'C'
    0x786C6666666C7800, // 68 'D'
    0x7E60607C60607E00, // 69 'E'
    0x7E60607C60606000, // 70 'F'
    0x3C66606E66663C00, // 71 'G'
    0x6666667E66666600, // 72 'H'
    0x7E18181818187E00, // 73 'I'
    0x0606060606663C00, // 74 'J'
    0x666C7870786C6600, // 75 'K'
    0x6060606060607E00, // 76 'L'
    0x63777F6B6B636300, // 77 'M'
    0x6676665E66666600, // 78 'N'
    0x3C66666666663C00, // 79 'O'
    0x7C66667C60606000, // 80 'P'
    0x3C6666666A6C3600, // 81 'Q'
    0x7C66667C6C666600, // 82 'R'
    0x3C66603C06663C00, // 83 'S'
    0x7E18181818181800, // 84 'T'
    0x6666666666663C00, // 85 'U'
    0x66666666663C1800, // 86 'V'
    0x63636B6B7F776300, // 87 'W'
    0x66663C183C666600, // 88 'X'
    0x6666663C18181800, // 89 'Y'
    0x7E060C1830607E00, // 90 'Z'
    0x3C30303030303C00, // 91 '['
    0x406030180C060200, // 92 '\'
    0x3C0C0C0C0C0C3C00, // 93 ']'
    0x183C664200000000, // 94 '^'
    0x00000000000000FF, // 95 '_'
    0x1818180000000000, // 96 '`'
    0x00003C063E663E00, // 97 'a'
    0x60607C6666667C00, // 98 'b'
    0x00003C6060603C00, // 99 'c'
    0x06063E6666663E00, // 100 'd'
    0x00003C667E603C00, // 101 'e'
    0x1C303C3030303000, // 102 'f'
    0x00003E66663E063C, // 103 'g'
    0x60607C6666666600, // 104 'h'
    0x1800181818180C00, // 105 'i'
    0x0C000C0C0C0C0C38, // 106 'j'
    0x6060666C786C6600, // 107 'k'
    0x1818181818180C00, // 108 'l'
    0x0000367F6B6B6300, // 109 'm'
    0x00007C6666666600, // 110 'n'
    0x00003C6666663C00, // 111 'o'
    0x00007C66667C6060, // 112 'p'
    0x00003E66663E0606, // 113 'q'
    0x00007C6660606000, // 114 'r'
    0x00003E603C067C00, // 115 's'
    0x30307C3030301C00, // 116 't'
    0x0000666666663E00, // 117 'u'
    0x00006666663C1800, // 118 'v'
    0x0000636B6B7F3600, // 119 'w'
    0x0000663C183C6600, // 120 'x'
    0x00006666663E063C, // 121 'y'
    0x00007E0C18307E00, // 122 'z'
    0x0E18187018180E00, // 123 '{'
    0x1818180018181800, // 124 '|'
    0x70180E0E18187000, // 125 '}'
    0x3B6E000000000000, // 126 '~'
};

var font_texture: c_uint = 0;
var initialized: bool = false;

pub fn init() void {
    if (initialized) return;

    // Create font texture (96 chars x 8 pixels wide, 8 pixels tall)
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

pub fn drawChar(x: f32, y: f32, char: u8, scale: f32) void {
    if (char < 32 or char > 126) return;

    const char_idx: f32 = @floatFromInt(char - 32);
    const tex_x = char_idx * 8.0 / (96.0 * 8.0);
    const tex_w = 8.0 / (96.0 * 8.0);

    const w = 8.0 * scale;
    const h = 8.0 * scale;

    gl.glTexCoord2f(tex_x, 0);
    gl.glVertex2f(x, y);
    gl.glTexCoord2f(tex_x + tex_w, 0);
    gl.glVertex2f(x + w, y);
    gl.glTexCoord2f(tex_x + tex_w, 1);
    gl.glVertex2f(x + w, y + h);
    gl.glTexCoord2f(tex_x, 1);
    gl.glVertex2f(x, y + h);
}

pub fn drawText(x: f32, y: f32, text: []const u8, scale: f32) void {
    var px = x;
    for (text) |char| {
        if (char == '\n') {
            px = x;
            continue;
        }
        drawChar(px, y, char, scale);
        px += 8.0 * scale;
    }
}

pub fn drawTextLine(x: f32, y: f32, text: []const u8, scale: f32, r: f32, g: f32, b: f32) void {
    gl.glColor4f(r, g, b, 1.0);
    gl.glBegin(gl.GL_QUADS);
    drawText(x, y, text, scale);
    gl.glEnd();
}

fn floatToStr(buf: []u8, value: f32) []const u8 {
    return std.fmt.bufPrint(buf, "{d:.2}", .{value}) catch "?";
}

fn intToStr(buf: []u8, value: i32) []const u8 {
    return std.fmt.bufPrint(buf, "{d}", .{value}) catch "?";
}

pub fn render(width: i32, height: i32, effects: anytype, show: bool) void {
    if (!show) return;
    if (!initialized) init();

    // Set up 2D orthographic projection
    gl.glMatrixMode(gl.GL_PROJECTION);
    gl.glPushMatrix();
    gl.glLoadIdentity();
    gl.glOrtho(0, @floatFromInt(width), @floatFromInt(height), 0, -1, 1);
    gl.glMatrixMode(gl.GL_MODELVIEW);
    gl.glPushMatrix();
    gl.glLoadIdentity();

    gl.glEnable(gl.GL_BLEND);
    gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA);

    // Draw semi-transparent background panel
    gl.glDisable(gl.GL_TEXTURE_2D);
    gl.glColor4f(0.0, 0.0, 0.0, 0.75);
    gl.glBegin(gl.GL_QUADS);
    gl.glVertex2f(10, 10);
    gl.glVertex2f(320, 10);
    gl.glVertex2f(320, 580);
    gl.glVertex2f(10, 580);
    gl.glEnd();

    // Draw border
    gl.glColor4f(0.3, 0.6, 1.0, 1.0);
    gl.glLineWidth(2);
    gl.glBegin(gl.GL_LINE_LOOP);
    gl.glVertex2f(10, 10);
    gl.glVertex2f(320, 10);
    gl.glVertex2f(320, 580);
    gl.glVertex2f(10, 580);
    gl.glEnd();

    // Enable font texture
    gl.glEnable(gl.GL_TEXTURE_2D);
    gl.glBindTexture(gl.GL_TEXTURE_2D, font_texture);

    const scale: f32 = 1.5;
    const line_height: f32 = 12.0 * scale;
    var y: f32 = 20;
    var buf: [64]u8 = undefined;

    // Title
    drawTextLine(20, y, "=== RAYTRACER CONTROLS ===", scale, 0.3, 0.8, 1.0);
    y += line_height * 1.5;

    // Camera section
    drawTextLine(20, y, "-- CAMERA --", scale, 1.0, 1.0, 0.5);
    y += line_height;

    const fov_str = floatToStr(&buf, effects.fov);
    var line_buf: [64]u8 = undefined;
    const fov_line = std.fmt.bufPrint(&line_buf, "FOV: {s}  (F/G)", .{fov_str}) catch "?";
    drawTextLine(20, y, fov_line, scale, 0.8, 0.8, 0.8);
    y += line_height;

    const apt_str = floatToStr(&buf, effects.aperture);
    const apt_line = std.fmt.bufPrint(&line_buf, "Aperture: {s}  (T/Y)", .{apt_str}) catch "?";
    drawTextLine(20, y, apt_line, scale, 0.8, 0.8, 0.8);
    y += line_height;

    const foc_str = floatToStr(&buf, effects.focus_dist);
    const foc_line = std.fmt.bufPrint(&line_buf, "Focus: {s}  (U/I)", .{foc_str}) catch "?";
    drawTextLine(20, y, foc_line, scale, 0.8, 0.8, 0.8);
    y += line_height;

    const samp_str = intToStr(&buf, @intCast(effects.samples_per_frame));
    const samp_line = std.fmt.bufPrint(&line_buf, "Samples: {s}  (1-4)", .{samp_str}) catch "?";
    drawTextLine(20, y, samp_line, scale, 0.8, 0.8, 0.8);
    y += line_height * 1.3;

    // Effects section
    drawTextLine(20, y, "-- POST EFFECTS --", scale, 1.0, 1.0, 0.5);
    y += line_height;

    // Column format for effects
    const effects_list = [_]struct { name: []const u8, key: []const u8, value: f32 }{
        .{ .name = "Bloom", .key = "B", .value = effects.bloom_strength },
        .{ .name = "Exposure", .key = "E", .value = effects.exposure },
        .{ .name = "Chromatic", .key = "C", .value = effects.chromatic_strength },
        .{ .name = "Vignette", .key = "V", .value = effects.vignette_strength },
        .{ .name = "Film Grain", .key = "G", .value = effects.film_grain },
        .{ .name = "Lens Flare", .key = "L", .value = effects.lens_flare },
        .{ .name = "Dispersion", .key = "Y", .value = effects.dispersion },
        .{ .name = "Heat Haze", .key = "X", .value = effects.heat_haze },
        .{ .name = "Scanlines", .key = "9", .value = effects.scanlines },
        .{ .name = "Tilt-Shift", .key = "0", .value = effects.tilt_shift },
        .{ .name = "Sepia", .key = "[", .value = effects.sepia },
        .{ .name = "Dither", .key = ";", .value = effects.dither },
    };

    for (effects_list) |eff| {
        const val_str = floatToStr(&buf, eff.value);
        const eff_line = std.fmt.bufPrint(&line_buf, "{s}: {s} ({s})", .{ eff.name, val_str, eff.key }) catch "?";
        const color: f32 = if (eff.value > 0.01) 0.5 else 0.8;
        drawTextLine(20, y, eff_line, scale, color, 1.0, color);
        y += line_height;
    }

    y += line_height * 0.3;

    // Vision modes
    drawTextLine(20, y, "-- VISION MODES --", scale, 1.0, 1.0, 0.5);
    y += line_height;

    const vision_list = [_]struct { name: []const u8, key: []const u8, value: f32 }{
        .{ .name = "Night Vision", .key = "F5", .value = effects.night_vision },
        .{ .name = "Thermal", .key = "F6", .value = effects.thermal },
        .{ .name = "Underwater", .key = "F7", .value = effects.underwater },
        .{ .name = "Fisheye", .key = "F11", .value = effects.fisheye },
        .{ .name = "Kaleidoscope", .key = "F1", .value = effects.kaleidoscope },
        .{ .name = "Pixelate", .key = "F2", .value = effects.pixelate },
        .{ .name = "Halftone", .key = "F4", .value = effects.halftone },
        .{ .name = "VHS", .key = "F9", .value = effects.vhs_effect },
        .{ .name = "3D Anaglyph", .key = "F10", .value = effects.anaglyph_3d },
    };

    for (vision_list) |vis| {
        const val_str = floatToStr(&buf, vis.value);
        const vis_line = std.fmt.bufPrint(&line_buf, "{s}: {s} ({s})", .{ vis.name, val_str, vis.key }) catch "?";
        const color: f32 = if (vis.value > 0.01) 0.5 else 0.8;
        drawTextLine(20, y, vis_line, scale, 1.0, color, color);
        y += line_height;
    }

    y += line_height * 0.3;

    // Help
    drawTextLine(20, y, "TAB: Toggle HUD", scale, 0.5, 0.5, 0.5);
    y += line_height;
    drawTextLine(20, y, "SHIFT+Key: Decrease", scale, 0.5, 0.5, 0.5);
    y += line_height;
    drawTextLine(20, y, "F12: Screenshot", scale, 0.5, 0.5, 0.5);

    // Restore state
    gl.glDisable(gl.GL_BLEND);
    gl.glDisable(gl.GL_TEXTURE_2D);
    gl.glMatrixMode(gl.GL_PROJECTION);
    gl.glPopMatrix();
    gl.glMatrixMode(gl.GL_MODELVIEW);
    gl.glPopMatrix();
}
