const std = @import("std");
const types = @import("types.zig");

const GPUSphere = types.GPUSphere;

// ============================================================================
// UNDO/REDO HISTORY SYSTEM
// ============================================================================

pub const ActionType = enum {
    add_object,
    remove_object,
    modify_object,
    move_camera,
    reset_scene,
};

pub const HistoryAction = struct {
    action_type: ActionType,
    // For add/remove/modify object
    object_index: ?usize = null,
    object_data: ?GPUSphere = null,
    previous_data: ?GPUSphere = null, // For modify
    // For camera
    camera_pos: ?[3]f32 = null,
    camera_yaw: ?f32 = null,
    camera_pitch: ?f32 = null,
    camera_roll: ?f32 = null,
    prev_camera_pos: ?[3]f32 = null,
    prev_camera_yaw: ?f32 = null,
    prev_camera_pitch: ?f32 = null,
    prev_camera_roll: ?f32 = null,
    // For reset
    previous_objects: ?[]GPUSphere = null,
};

const MAX_HISTORY = 50;

pub const History = struct {
    undo_stack: std.ArrayList(HistoryAction),
    redo_stack: std.ArrayList(HistoryAction),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) History {
        return .{
            .undo_stack = .empty,
            .redo_stack = .empty,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *History) void {
        // Free any allocated object arrays
        for (self.undo_stack.items) |action| {
            if (action.previous_objects) |objs| {
                self.allocator.free(objs);
            }
        }
        for (self.redo_stack.items) |action| {
            if (action.previous_objects) |objs| {
                self.allocator.free(objs);
            }
        }
        self.undo_stack.deinit(self.allocator);
        self.redo_stack.deinit(self.allocator);
    }

    pub fn pushAction(self: *History, action: HistoryAction) void {
        // Clear redo stack when new action is performed
        for (self.redo_stack.items) |redo_action| {
            if (redo_action.previous_objects) |objs| {
                self.allocator.free(objs);
            }
        }
        self.redo_stack.clearRetainingCapacity();

        // Limit history size
        if (self.undo_stack.items.len >= MAX_HISTORY) {
            if (self.undo_stack.items[0].previous_objects) |objs| {
                self.allocator.free(objs);
            }
            _ = self.undo_stack.orderedRemove(0);
        }

        self.undo_stack.append(self.allocator, action) catch {};
    }

    pub fn recordAddObject(self: *History, index: usize, object: GPUSphere) void {
        self.pushAction(.{
            .action_type = .add_object,
            .object_index = index,
            .object_data = object,
        });
    }

    pub fn recordRemoveObject(self: *History, index: usize, object: GPUSphere) void {
        self.pushAction(.{
            .action_type = .remove_object,
            .object_index = index,
            .object_data = object,
        });
    }

    pub fn recordModifyObject(self: *History, index: usize, previous: GPUSphere, current: GPUSphere) void {
        self.pushAction(.{
            .action_type = .modify_object,
            .object_index = index,
            .object_data = current,
            .previous_data = previous,
        });
    }

    pub fn recordCameraMove(
        self: *History,
        prev_pos: [3]f32,
        prev_yaw: f32,
        prev_pitch: f32,
        prev_roll: f32,
        new_pos: [3]f32,
        new_yaw: f32,
        new_pitch: f32,
        new_roll: f32,
    ) void {
        self.pushAction(.{
            .action_type = .move_camera,
            .camera_pos = new_pos,
            .camera_yaw = new_yaw,
            .camera_pitch = new_pitch,
            .camera_roll = new_roll,
            .prev_camera_pos = prev_pos,
            .prev_camera_yaw = prev_yaw,
            .prev_camera_pitch = prev_pitch,
            .prev_camera_roll = prev_roll,
        });
    }

    pub fn recordResetScene(self: *History, previous_objects: []const GPUSphere) void {
        const copy = self.allocator.dupe(GPUSphere, previous_objects) catch return;
        self.pushAction(.{
            .action_type = .reset_scene,
            .previous_objects = copy,
        });
    }

    pub fn canUndo(self: *const History) bool {
        return self.undo_stack.items.len > 0;
    }

    pub fn canRedo(self: *const History) bool {
        return self.redo_stack.items.len > 0;
    }

    pub fn undo(
        self: *History,
        spheres: *std.ArrayList(GPUSphere),
        camera_pos: *[3]f32,
        camera_yaw: *f32,
        camera_pitch: *f32,
        camera_roll: *f32,
    ) bool {
        if (self.undo_stack.items.len == 0) return false;

        const action = self.undo_stack.pop();

        switch (action.action_type) {
            .add_object => {
                // Undo add = remove
                if (action.object_index) |idx| {
                    if (idx < spheres.items.len) {
                        _ = spheres.orderedRemove(idx);
                    }
                }
            },
            .remove_object => {
                // Undo remove = add back
                if (action.object_index) |idx| {
                    if (action.object_data) |obj| {
                        spheres.insert(self.allocator, idx, obj) catch {};
                    }
                }
            },
            .modify_object => {
                // Undo modify = restore previous
                if (action.object_index) |idx| {
                    if (idx < spheres.items.len) {
                        if (action.previous_data) |prev| {
                            spheres.items[idx] = prev;
                        }
                    }
                }
            },
            .move_camera => {
                if (action.prev_camera_pos) |pos| camera_pos.* = pos;
                if (action.prev_camera_yaw) |y| camera_yaw.* = y;
                if (action.prev_camera_pitch) |p| camera_pitch.* = p;
                if (action.prev_camera_roll) |r| camera_roll.* = r;
            },
            .reset_scene => {
                // Undo reset = restore previous objects
                if (action.previous_objects) |prev_objs| {
                    spheres.clearRetainingCapacity();
                    for (prev_objs) |obj| {
                        spheres.append(self.allocator, obj) catch {};
                    }
                }
            },
        }

        // Push to redo stack
        self.redo_stack.append(self.allocator, action) catch {};
        return true;
    }

    pub fn redo(
        self: *History,
        spheres: *std.ArrayList(GPUSphere),
        camera_pos: *[3]f32,
        camera_yaw: *f32,
        camera_pitch: *f32,
        camera_roll: *f32,
    ) bool {
        if (self.redo_stack.items.len == 0) return false;

        const action = self.redo_stack.pop();

        switch (action.action_type) {
            .add_object => {
                // Redo add = add
                if (action.object_index) |idx| {
                    if (action.object_data) |obj| {
                        spheres.insert(self.allocator, idx, obj) catch {};
                    }
                }
            },
            .remove_object => {
                // Redo remove = remove
                if (action.object_index) |idx| {
                    if (idx < spheres.items.len) {
                        _ = spheres.orderedRemove(idx);
                    }
                }
            },
            .modify_object => {
                // Redo modify = apply new
                if (action.object_index) |idx| {
                    if (idx < spheres.items.len) {
                        if (action.object_data) |new| {
                            spheres.items[idx] = new;
                        }
                    }
                }
            },
            .move_camera => {
                if (action.camera_pos) |pos| camera_pos.* = pos;
                if (action.camera_yaw) |y| camera_yaw.* = y;
                if (action.camera_pitch) |p| camera_pitch.* = p;
                if (action.camera_roll) |r| camera_roll.* = r;
            },
            .reset_scene => {
                // Redo reset = clear scene
                spheres.clearRetainingCapacity();
            },
        }

        // Push back to undo stack
        self.undo_stack.append(self.allocator, action) catch {};
        return true;
    }

    pub fn getUndoCount(self: *const History) usize {
        return self.undo_stack.items.len;
    }

    pub fn getRedoCount(self: *const History) usize {
        return self.redo_stack.items.len;
    }
};

// Global history instance
pub var global: ?History = null;

pub fn init(allocator: std.mem.Allocator) void {
    global = History.init(allocator);
}

pub fn deinit() void {
    if (global) |*h| {
        h.deinit();
        global = null;
    }
}

// Simple wrapper functions for common operations
pub fn recordAddObject(sphere: GPUSphere) void {
    if (global) |*h| {
        // Use a counter for index since we just track sphere data
        const idx = h.undo_stack.items.len;
        h.recordAddObject(idx, sphere);
    }
}

pub fn recordRemoveObject(sphere: GPUSphere) void {
    if (global) |*h| {
        const idx = if (h.undo_stack.items.len > 0) h.undo_stack.items.len - 1 else 0;
        h.recordRemoveObject(idx, sphere);
    }
}

pub fn clear() void {
    if (global) |*h| {
        // Clear redo stack
        for (h.redo_stack.items) |action| {
            if (action.previous_objects) |objs| {
                h.allocator.free(objs);
            }
        }
        h.redo_stack.clearRetainingCapacity();
        // Clear undo stack
        for (h.undo_stack.items) |action| {
            if (action.previous_objects) |objs| {
                h.allocator.free(objs);
            }
        }
        h.undo_stack.clearRetainingCapacity();
    }
}

// Simple undo that returns the action for caller to handle
pub fn undo() ?HistoryAction {
    if (global) |*h| {
        if (h.undo_stack.items.len == 0) return null;
        const action = h.undo_stack.pop() orelse return null;
        h.redo_stack.append(h.allocator, action) catch {};
        return action;
    }
    return null;
}

// Simple redo that returns the action for caller to handle
pub fn redo() ?HistoryAction {
    if (global) |*h| {
        if (h.redo_stack.items.len == 0) return null;
        const action = h.redo_stack.pop() orelse return null;
        h.undo_stack.append(h.allocator, action) catch {};
        return action;
    }
    return null;
}

pub fn canUndo() bool {
    if (global) |*h| {
        return h.canUndo();
    }
    return false;
}

pub fn canRedo() bool {
    if (global) |*h| {
        return h.canRedo();
    }
    return false;
}

pub fn getCount() usize {
    if (global) |*h| {
        return h.undo_stack.items.len;
    }
    return 0;
}
