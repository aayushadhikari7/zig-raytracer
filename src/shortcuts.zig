const std = @import("std");

// ============================================================================
// KEYBOARD SHORTCUTS REFERENCE
// Centralized shortcut definitions for consistency
// ============================================================================

pub const ShortcutCategory = enum {
    file,
    view,
    camera,
    spawn,
    effects,
    quality,
    debug,
};

pub const Shortcut = struct {
    key: []const u8,
    description: []const u8,
    category: ShortcutCategory,
};

// All shortcuts in one place for easy reference and modification
pub const shortcuts = [_]Shortcut{
    // FILE
    .{ .key = "Ctrl+N", .description = "New Scene", .category = .file },
    .{ .key = "Ctrl+O", .description = "Open Scene", .category = .file },
    .{ .key = "Ctrl+S", .description = "Save Scene", .category = .file },
    .{ .key = "Ctrl+E", .description = "Export PNG", .category = .file },
    .{ .key = "F12", .description = "Quick Screenshot", .category = .file },
    .{ .key = "Ctrl+Z", .description = "Undo", .category = .file },
    .{ .key = "Ctrl+Y", .description = "Redo", .category = .file },

    // VIEW
    .{ .key = "TAB", .description = "Toggle HUD", .category = .view },
    .{ .key = "~", .description = "Toggle Console", .category = .view },
    .{ .key = "H", .description = "Toggle Help", .category = .view },
    .{ .key = "P", .description = "Toggle Flight Mode", .category = .view },

    // CAMERA
    .{ .key = "W/S", .description = "Forward/Back", .category = .camera },
    .{ .key = "A/D", .description = "Strafe Left/Right", .category = .camera },
    .{ .key = "Space", .description = "Move Up", .category = .camera },
    .{ .key = "Ctrl", .description = "Move Down", .category = .camera },
    .{ .key = "Q/E", .description = "Roll (Flight Mode)", .category = .camera },
    .{ .key = "Right Click", .description = "Toggle Mouse Look", .category = .camera },
    .{ .key = "F/G", .description = "FOV -/+", .category = .camera },
    .{ .key = "T/Y", .description = "Aperture -/+", .category = .camera },
    .{ .key = "U/I", .description = "Focus Distance -/+", .category = .camera },
    .{ .key = "R", .description = "Reset Camera & Effects", .category = .camera },

    // SPAWN
    .{ .key = "Ctrl+1", .description = "Spawn Diffuse Sphere", .category = .spawn },
    .{ .key = "Ctrl+2", .description = "Spawn Metal Sphere", .category = .spawn },
    .{ .key = "Ctrl+3", .description = "Spawn Glass Sphere", .category = .spawn },
    .{ .key = "Ctrl+4", .description = "Spawn Light", .category = .spawn },
    .{ .key = "Ctrl+5", .description = "Spawn SSS Sphere", .category = .spawn },
    .{ .key = "Ctrl+6", .description = "Spawn Carved Sphere (CSG)", .category = .spawn },
    .{ .key = "Ctrl+7", .description = "Spawn Organic Blob (CSG)", .category = .spawn },
    .{ .key = "Ctrl+8", .description = "Spawn Rounded Cube (CSG)", .category = .spawn },
    .{ .key = "Ctrl+9", .description = "Spawn Icosphere Mesh", .category = .spawn },
    .{ .key = "Ctrl+0", .description = "Load OBJ File", .category = .spawn },
    .{ .key = "Del", .description = "Remove Last Object", .category = .spawn },
    .{ .key = "Ctrl+D", .description = "Toggle Demo Scene", .category = .spawn },

    // EFFECTS (hold Shift to decrease)
    .{ .key = "B", .description = "Bloom +/-", .category = .effects },
    .{ .key = "E", .description = "Exposure +/-", .category = .effects },
    .{ .key = "C", .description = "Chromatic Aberration +/-", .category = .effects },
    .{ .key = "V", .description = "Vignette +/-", .category = .effects },
    .{ .key = "M", .description = "Motion Blur +/-", .category = .effects },
    .{ .key = "G", .description = "Film Grain +/-", .category = .effects },
    .{ .key = "L", .description = "Lens Flare +/-", .category = .effects },
    .{ .key = "X", .description = "Heat Haze +/-", .category = .effects },
    .{ .key = "N", .description = "Toggle NEE", .category = .effects },
    .{ .key = "F1", .description = "Kaleidoscope +/-", .category = .effects },
    .{ .key = "F2", .description = "Pixelate +/-", .category = .effects },
    .{ .key = "F3", .description = "Edge Detect +/-", .category = .effects },
    .{ .key = "F4", .description = "Halftone +/-", .category = .effects },
    .{ .key = "F5", .description = "Night Vision +/-", .category = .effects },
    .{ .key = "F6", .description = "Thermal +/-", .category = .effects },
    .{ .key = "F7", .description = "Underwater +/-", .category = .effects },
    .{ .key = "F9", .description = "VHS Effect +/-", .category = .effects },
    .{ .key = "F11", .description = "Fisheye +/-", .category = .effects },

    // QUALITY
    .{ .key = "1", .description = "2 SPP (Fast)", .category = .quality },
    .{ .key = "2", .description = "4 SPP", .category = .quality },
    .{ .key = "3", .description = "8 SPP", .category = .quality },
    .{ .key = "4", .description = "16 SPP (Slow)", .category = .quality },

    // DEBUG
    .{ .key = "5", .description = "Normal Render", .category = .debug },
    .{ .key = "6", .description = "BVH Heatmap", .category = .debug },
    .{ .key = "7", .description = "Show Normals", .category = .debug },
    .{ .key = "8", .description = "Show Depth", .category = .debug },
    .{ .key = "ESC", .description = "Exit", .category = .debug },
};

pub fn getShortcutsByCategory(category: ShortcutCategory) []const Shortcut {
    var start: usize = 0;
    var end: usize = 0;
    var in_category = false;

    for (shortcuts, 0..) |s, i| {
        if (s.category == category) {
            if (!in_category) {
                start = i;
                in_category = true;
            }
            end = i + 1;
        } else if (in_category) {
            break;
        }
    }

    return shortcuts[start..end];
}

pub fn getCategoryName(category: ShortcutCategory) []const u8 {
    return switch (category) {
        .file => "File",
        .view => "View",
        .camera => "Camera",
        .spawn => "Spawn Objects",
        .effects => "Effects (Shift=Dec)",
        .quality => "Quality",
        .debug => "Debug",
    };
}

// Format all shortcuts as a string for help display
pub fn formatAllShortcuts(buf: []u8) []const u8 {
    var stream = std.io.fixedBufferStream(buf);
    var writer = stream.writer();

    const categories = [_]ShortcutCategory{ .file, .view, .camera, .spawn, .effects, .quality, .debug };

    for (categories) |cat| {
        writer.print("\n{s}:\n", .{getCategoryName(cat)}) catch break;
        for (shortcuts) |s| {
            if (s.category == cat) {
                writer.print("  {s: <12} {s}\n", .{ s.key, s.description }) catch break;
            }
        }
    }

    return stream.getWritten();
}
