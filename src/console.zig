const std = @import("std");
const types = @import("types.zig");
const scene = @import("scene.zig");
const profiler = @import("profiler.zig");

const GPUSphere = types.GPUSphere;

// ============================================================================
// CONSOLE COMMAND SYSTEM - Interactive debug commands
// ============================================================================

pub const CommandResult = struct {
    success: bool,
    message: []const u8,
    scene_changed: bool = false,
    camera_changed: bool = false,
};

pub const Console = struct {
    history: std.ArrayList([]const u8),
    output: std.ArrayList([]const u8),
    input_buffer: [256]u8 = [_]u8{0} ** 256,
    input_len: usize = 0,
    cursor_pos: usize = 0,
    history_pos: ?usize = null,
    allocator: std.mem.Allocator,

    // References to scene state (set externally)
    spheres: ?*std.ArrayList(GPUSphere) = null,
    camera_pos: ?*[3]f32 = null,
    camera_yaw: ?*f32 = null,
    camera_pitch: ?*f32 = null,

    pub fn init(allocator: std.mem.Allocator) Console {
        return .{
            .history = std.ArrayList([]const u8).init(allocator),
            .output = std.ArrayList([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Console) void {
        for (self.history.items) |item| {
            self.allocator.free(item);
        }
        self.history.deinit();
        for (self.output.items) |item| {
            self.allocator.free(item);
        }
        self.output.deinit();
    }

    pub fn addChar(self: *Console, char: u8) void {
        if (self.input_len < self.input_buffer.len - 1) {
            // Insert at cursor
            if (self.cursor_pos < self.input_len) {
                std.mem.copyBackwards(u8, self.input_buffer[self.cursor_pos + 1 .. self.input_len + 1], self.input_buffer[self.cursor_pos..self.input_len]);
            }
            self.input_buffer[self.cursor_pos] = char;
            self.input_len += 1;
            self.cursor_pos += 1;
        }
    }

    pub fn backspace(self: *Console) void {
        if (self.cursor_pos > 0) {
            std.mem.copyForwards(u8, self.input_buffer[self.cursor_pos - 1 .. self.input_len - 1], self.input_buffer[self.cursor_pos..self.input_len]);
            self.input_len -= 1;
            self.cursor_pos -= 1;
        }
    }

    pub fn cursorLeft(self: *Console) void {
        if (self.cursor_pos > 0) self.cursor_pos -= 1;
    }

    pub fn cursorRight(self: *Console) void {
        if (self.cursor_pos < self.input_len) self.cursor_pos += 1;
    }

    pub fn historyUp(self: *Console) void {
        if (self.history.items.len == 0) return;
        if (self.history_pos) |pos| {
            if (pos > 0) self.history_pos = pos - 1;
        } else {
            self.history_pos = self.history.items.len - 1;
        }
        if (self.history_pos) |pos| {
            const cmd = self.history.items[pos];
            @memcpy(self.input_buffer[0..cmd.len], cmd);
            self.input_len = cmd.len;
            self.cursor_pos = cmd.len;
        }
    }

    pub fn historyDown(self: *Console) void {
        if (self.history_pos) |pos| {
            if (pos < self.history.items.len - 1) {
                self.history_pos = pos + 1;
                const cmd = self.history.items[self.history_pos.?];
                @memcpy(self.input_buffer[0..cmd.len], cmd);
                self.input_len = cmd.len;
                self.cursor_pos = cmd.len;
            } else {
                self.history_pos = null;
                self.input_len = 0;
                self.cursor_pos = 0;
            }
        }
    }

    pub fn execute(self: *Console) CommandResult {
        if (self.input_len == 0) {
            return .{ .success = true, .message = "" };
        }

        const input = self.input_buffer[0..self.input_len];

        // Add to history
        const hist_copy = self.allocator.dupe(u8, input) catch {
            return .{ .success = false, .message = "Memory error" };
        };
        self.history.append(hist_copy) catch {};
        self.history_pos = null;

        // Parse and execute
        const result = self.parseAndExecute(input);

        // Add output
        const out_copy = self.allocator.dupe(u8, result.message) catch "";
        self.output.append(out_copy) catch {};

        // Clear input
        self.input_len = 0;
        self.cursor_pos = 0;

        return result;
    }

    fn parseAndExecute(self: *Console, input: []const u8) CommandResult {
        var iter = std.mem.splitScalar(u8, input, ' ');
        const cmd = iter.next() orelse return .{ .success = false, .message = "Empty command" };

        if (std.mem.eql(u8, cmd, "help")) {
            return .{
                .success = true,
                .message =
                \\Commands:
                \\  help              - Show this help
                \\  clear             - Clear console output
                \\  spawn <type> [x y z] - Spawn object (diffuse/metal/glass/light/sss)
                \\  remove [index]    - Remove last or specific object
                \\  list              - List all objects
                \\  camera [x y z]    - Set or show camera position
                \\  look [yaw pitch]  - Set camera rotation
                \\  reset             - Reset scene
                \\  stats             - Show profiler stats
                \\  set <var> <val>   - Set variable (exposure, bloom, etc)
                ,
            };
        }

        if (std.mem.eql(u8, cmd, "clear")) {
            for (self.output.items) |item| {
                self.allocator.free(item);
            }
            self.output.clearRetainingCapacity();
            return .{ .success = true, .message = "Console cleared" };
        }

        if (std.mem.eql(u8, cmd, "stats")) {
            var buf: [1024]u8 = undefined;
            const stats = profiler.global.formatStats(&buf);
            const copy = self.allocator.dupe(u8, stats) catch return .{ .success = false, .message = "Memory error" };
            return .{ .success = true, .message = copy };
        }

        if (std.mem.eql(u8, cmd, "list")) {
            if (self.spheres) |spheres| {
                var buf: [2048]u8 = undefined;
                var stream = std.io.fixedBufferStream(&buf);
                var writer = stream.writer();
                writer.print("Objects ({}):\n", .{spheres.items.len}) catch {};
                for (spheres.items, 0..) |s, i| {
                    const mat_name = switch (s.mat_type) {
                        0 => "Diffuse",
                        1 => "Metal",
                        2 => "Glass",
                        3 => "Emissive",
                        4 => "SSS",
                        else => "Unknown",
                    };
                    writer.print("  [{d}] {s} at ({d:.1},{d:.1},{d:.1}) r={d:.2}\n", .{ i, mat_name, s.center[0], s.center[1], s.center[2], s.radius }) catch {};
                }
                const copy = self.allocator.dupe(u8, stream.getWritten()) catch return .{ .success = false, .message = "Memory error" };
                return .{ .success = true, .message = copy };
            }
            return .{ .success = false, .message = "Scene not connected" };
        }

        if (std.mem.eql(u8, cmd, "spawn")) {
            const type_str = iter.next() orelse return .{ .success = false, .message = "Usage: spawn <type> [x y z]" };

            var pos: [3]f32 = scene.getNextSpawnPosition();

            // Parse optional position
            if (iter.next()) |x_str| {
                pos[0] = std.fmt.parseFloat(f32, x_str) catch pos[0];
                if (iter.next()) |y_str| {
                    pos[1] = std.fmt.parseFloat(f32, y_str) catch pos[1];
                    if (iter.next()) |z_str| {
                        pos[2] = std.fmt.parseFloat(f32, z_str) catch pos[2];
                    }
                }
            }

            if (self.spheres) |spheres| {
                const sphere = if (std.mem.eql(u8, type_str, "diffuse"))
                    scene.createDiffuseSphere(pos)
                else if (std.mem.eql(u8, type_str, "metal"))
                    scene.createMetalSphere(pos)
                else if (std.mem.eql(u8, type_str, "glass"))
                    scene.createGlassSphere(pos)
                else if (std.mem.eql(u8, type_str, "light"))
                    scene.createLightSphere(pos)
                else if (std.mem.eql(u8, type_str, "sss"))
                    scene.createSSSSphere(pos)
                else
                    return .{ .success = false, .message = "Unknown type. Use: diffuse/metal/glass/light/sss" };

                spheres.append(self.allocator, sphere) catch return .{ .success = false, .message = "Failed to add object" };
                return .{ .success = true, .message = "Object spawned", .scene_changed = true };
            }
            return .{ .success = false, .message = "Scene not connected" };
        }

        if (std.mem.eql(u8, cmd, "remove")) {
            if (self.spheres) |spheres| {
                if (iter.next()) |idx_str| {
                    const idx = std.fmt.parseInt(usize, idx_str, 10) catch return .{ .success = false, .message = "Invalid index" };
                    if (idx >= spheres.items.len) return .{ .success = false, .message = "Index out of range" };
                    _ = spheres.orderedRemove(idx);
                } else {
                    if (spheres.items.len > 1) {
                        _ = spheres.pop();
                    } else {
                        return .{ .success = false, .message = "Cannot remove ground" };
                    }
                }
                return .{ .success = true, .message = "Object removed", .scene_changed = true };
            }
            return .{ .success = false, .message = "Scene not connected" };
        }

        if (std.mem.eql(u8, cmd, "camera")) {
            if (self.camera_pos) |cam| {
                if (iter.next()) |x_str| {
                    cam[0] = std.fmt.parseFloat(f32, x_str) catch cam[0];
                    if (iter.next()) |y_str| {
                        cam[1] = std.fmt.parseFloat(f32, y_str) catch cam[1];
                        if (iter.next()) |z_str| {
                            cam[2] = std.fmt.parseFloat(f32, z_str) catch cam[2];
                        }
                    }
                    return .{ .success = true, .message = "Camera moved", .camera_changed = true };
                } else {
                    var buf: [64]u8 = undefined;
                    const msg = std.fmt.bufPrint(&buf, "Camera at ({d:.2}, {d:.2}, {d:.2})", .{ cam[0], cam[1], cam[2] }) catch "?";
                    const copy = self.allocator.dupe(u8, msg) catch return .{ .success = false, .message = "Memory error" };
                    return .{ .success = true, .message = copy };
                }
            }
            return .{ .success = false, .message = "Camera not connected" };
        }

        if (std.mem.eql(u8, cmd, "reset")) {
            if (self.spheres) |spheres| {
                spheres.clearRetainingCapacity();
                scene.resetSpawnPosition();
                return .{ .success = true, .message = "Scene reset", .scene_changed = true };
            }
            return .{ .success = false, .message = "Scene not connected" };
        }

        return .{ .success = false, .message = "Unknown command. Type 'help' for commands." };
    }

    pub fn getInput(self: *const Console) []const u8 {
        return self.input_buffer[0..self.input_len];
    }

    pub fn getOutput(self: *const Console) []const []const u8 {
        return self.output.items;
    }
};

// Global console instance
pub var global: ?Console = null;

pub fn init(allocator: std.mem.Allocator) void {
    global = Console.init(allocator);
}

pub fn deinit() void {
    if (global) |*c| {
        c.deinit();
        global = null;
    }
}
