const std = @import("std");

// ============================================================================
// CAMERA BOOKMARKS/PRESETS SYSTEM
// Save and recall camera positions with hotkeys
// ============================================================================

pub const CameraBookmark = struct {
    name: [32]u8 = [_]u8{0} ** 32,
    name_len: usize = 0,
    pos: [3]f32 = .{ 0, 0, 0 },
    yaw: f32 = 0,
    pitch: f32 = 0,
    roll: f32 = 0,
    fov: f32 = 20.0,
    aperture: f32 = 0,
    focus_dist: f32 = 10.0,
    used: bool = false,
};

const MAX_BOOKMARKS = 10; // F1-F10 style slots (we use number keys)

pub const CameraPresets = struct {
    bookmarks: [MAX_BOOKMARKS]CameraBookmark = [_]CameraBookmark{.{}} ** MAX_BOOKMARKS,

    pub fn saveBookmark(
        self: *CameraPresets,
        slot: usize,
        name: []const u8,
        pos: [3]f32,
        yaw: f32,
        pitch: f32,
        roll: f32,
        fov: f32,
        aperture: f32,
        focus_dist: f32,
    ) bool {
        if (slot >= MAX_BOOKMARKS) return false;

        var bookmark = &self.bookmarks[slot];
        bookmark.used = true;
        bookmark.pos = pos;
        bookmark.yaw = yaw;
        bookmark.pitch = pitch;
        bookmark.roll = roll;
        bookmark.fov = fov;
        bookmark.aperture = aperture;
        bookmark.focus_dist = focus_dist;

        // Copy name
        const copy_len = @min(name.len, 31);
        @memcpy(bookmark.name[0..copy_len], name[0..copy_len]);
        bookmark.name_len = copy_len;

        return true;
    }

    pub fn loadBookmark(
        self: *const CameraPresets,
        slot: usize,
        pos: *[3]f32,
        yaw: *f32,
        pitch: *f32,
        roll: *f32,
        fov: *f32,
        aperture: *f32,
        focus_dist: *f32,
    ) bool {
        if (slot >= MAX_BOOKMARKS) return false;

        const bookmark = &self.bookmarks[slot];
        if (!bookmark.used) return false;

        pos.* = bookmark.pos;
        yaw.* = bookmark.yaw;
        pitch.* = bookmark.pitch;
        roll.* = bookmark.roll;
        fov.* = bookmark.fov;
        aperture.* = bookmark.aperture;
        focus_dist.* = bookmark.focus_dist;

        return true;
    }

    pub fn clearBookmark(self: *CameraPresets, slot: usize) void {
        if (slot >= MAX_BOOKMARKS) return;
        self.bookmarks[slot] = .{};
    }

    pub fn isSlotUsed(self: *const CameraPresets, slot: usize) bool {
        if (slot >= MAX_BOOKMARKS) return false;
        return self.bookmarks[slot].used;
    }

    pub fn getBookmarkName(self: *const CameraPresets, slot: usize) []const u8 {
        if (slot >= MAX_BOOKMARKS) return "";
        const bookmark = &self.bookmarks[slot];
        if (!bookmark.used) return "";
        return bookmark.name[0..bookmark.name_len];
    }

    pub fn getUsedCount(self: *const CameraPresets) usize {
        var count: usize = 0;
        for (self.bookmarks) |b| {
            if (b.used) count += 1;
        }
        return count;
    }
};

// Built-in camera presets for common views
pub const builtin_presets = struct {
    pub const front = CameraBookmark{
        .name = [_]u8{'F', 'r', 'o', 'n', 't'} ++ [_]u8{0} ** 27,
        .name_len = 5,
        .pos = .{ 0, 2, 10 },
        .yaw = 3.14159,
        .pitch = -0.1,
        .roll = 0,
        .fov = 20,
        .aperture = 0,
        .focus_dist = 10,
        .used = true,
    };

    pub const top = CameraBookmark{
        .name = [_]u8{'T', 'o', 'p'} ++ [_]u8{0} ** 29,
        .name_len = 3,
        .pos = .{ 0, 15, 0.01 },
        .yaw = 0,
        .pitch = -1.57,
        .roll = 0,
        .fov = 30,
        .aperture = 0,
        .focus_dist = 15,
        .used = true,
    };

    pub const side = CameraBookmark{
        .name = [_]u8{'S', 'i', 'd', 'e'} ++ [_]u8{0} ** 28,
        .name_len = 4,
        .pos = .{ 10, 2, 0 },
        .yaw = -1.5708,
        .pitch = -0.1,
        .roll = 0,
        .fov = 20,
        .aperture = 0,
        .focus_dist = 10,
        .used = true,
    };

    pub const dramatic = CameraBookmark{
        .name = [_]u8{'D', 'r', 'a', 'm', 'a', 't', 'i', 'c'} ++ [_]u8{0} ** 24,
        .name_len = 8,
        .pos = .{ 8, 4, 8 },
        .yaw = -2.356,
        .pitch = -0.3,
        .roll = 0,
        .fov = 25,
        .aperture = 0.05,
        .focus_dist = 11,
        .used = true,
    };

    pub const closeup = CameraBookmark{
        .name = [_]u8{'C', 'l', 'o', 's', 'e', '-', 'u', 'p'} ++ [_]u8{0} ** 24,
        .name_len = 8,
        .pos = .{ 2, 1.5, 2 },
        .yaw = -2.356,
        .pitch = -0.2,
        .roll = 0,
        .fov = 35,
        .aperture = 0.1,
        .focus_dist = 2.8,
        .used = true,
    };

    pub const wide = CameraBookmark{
        .name = [_]u8{'W', 'i', 'd', 'e'} ++ [_]u8{0} ** 28,
        .name_len = 4,
        .pos = .{ 0, 5, 20 },
        .yaw = 3.14159,
        .pitch = -0.2,
        .roll = 0,
        .fov = 60,
        .aperture = 0,
        .focus_dist = 20,
        .used = true,
    };
};

// Global instance
pub var global: CameraPresets = .{};

pub fn init() void {
    global = .{};
}

// Quick save current camera to slot (Ctrl+Shift+1-9)
pub fn quickSave(
    slot: usize,
    pos: [3]f32,
    yaw: f32,
    pitch: f32,
    roll: f32,
    fov: f32,
    aperture: f32,
    focus_dist: f32,
) bool {
    var name_buf: [16]u8 = undefined;
    const name = std.fmt.bufPrint(&name_buf, "Slot {}", .{slot + 1}) catch "Slot";
    return global.saveBookmark(slot, name, pos, yaw, pitch, roll, fov, aperture, focus_dist);
}

// Quick load from slot (Ctrl+1-9)
pub fn quickLoad(
    slot: usize,
    pos: *[3]f32,
    yaw: *f32,
    pitch: *f32,
    roll: *f32,
    fov: *f32,
    aperture: *f32,
    focus_dist: *f32,
) bool {
    return global.loadBookmark(slot, pos, yaw, pitch, roll, fov, aperture, focus_dist);
}
