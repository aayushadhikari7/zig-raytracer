const std = @import("std");

const win32 = @cImport({
    @cDefine("WIN32_LEAN_AND_MEAN", "1");
    @cInclude("windows.h");
});

// ============================================================================
// PERFORMANCE PROFILER - Track and display render metrics
// ============================================================================

pub const TimingSection = enum {
    frame_total,
    scene_upload,
    ray_generation,
    bvh_traversal,
    shading,
    post_processing,
    hud_render,
    swap_buffers,
};

const NUM_SECTIONS = @typeInfo(TimingSection).@"enum".fields.len;
const HISTORY_SIZE = 120; // 2 seconds at 60fps

// Use Windows high-performance counter
fn getTimeMicros() i64 {
    var freq: win32.LARGE_INTEGER = undefined;
    var counter: win32.LARGE_INTEGER = undefined;
    _ = win32.QueryPerformanceFrequency(&freq);
    _ = win32.QueryPerformanceCounter(&counter);
    return @divTrunc(counter.QuadPart * 1_000_000, freq.QuadPart);
}

pub const Profiler = struct {
    // Timing data
    section_times: [NUM_SECTIONS]f64 = [_]f64{0} ** NUM_SECTIONS,
    section_starts: [NUM_SECTIONS]i64 = [_]i64{0} ** NUM_SECTIONS,

    // History for graphs
    frame_history: [HISTORY_SIZE]f32 = [_]f32{0} ** HISTORY_SIZE,
    history_index: usize = 0,

    // Stats
    frame_count: u64 = 0,
    total_time: f64 = 0,
    min_frame_time: f64 = std.math.floatMax(f64),
    max_frame_time: f64 = 0,

    // Memory tracking
    gpu_memory_used: usize = 0,
    sphere_count: usize = 0,
    triangle_count: usize = 0,
    bvh_node_count: usize = 0,

    // Render stats
    samples_accumulated: u32 = 0,
    rays_per_frame: u64 = 0,

    pub fn init() Profiler {
        return .{};
    }

    pub fn startSection(self: *Profiler, section: TimingSection) void {
        self.section_starts[@intFromEnum(section)] = getTimeMicros();
    }

    pub fn endSection(self: *Profiler, section: TimingSection) void {
        const start_time = self.section_starts[@intFromEnum(section)];
        const end_time = getTimeMicros();
        self.section_times[@intFromEnum(section)] = @as(f64, @floatFromInt(end_time - start_time)) / 1000.0; // ms
    }

    pub fn getSectionTime(self: *const Profiler, section: TimingSection) f64 {
        return self.section_times[@intFromEnum(section)];
    }

    pub fn endFrame(self: *Profiler) void {
        const frame_time = self.section_times[@intFromEnum(TimingSection.frame_total)];

        // Update history
        self.frame_history[self.history_index] = @floatCast(frame_time);
        self.history_index = (self.history_index + 1) % HISTORY_SIZE;

        // Update stats
        self.frame_count += 1;
        self.total_time += frame_time;
        self.min_frame_time = @min(self.min_frame_time, frame_time);
        self.max_frame_time = @max(self.max_frame_time, frame_time);
    }

    pub fn getAverageFrameTime(self: *const Profiler) f64 {
        if (self.frame_count == 0) return 0;
        return self.total_time / @as(f64, @floatFromInt(self.frame_count));
    }

    pub fn getAverageFPS(self: *const Profiler) f64 {
        const avg = self.getAverageFrameTime();
        if (avg == 0) return 0;
        return 1000.0 / avg;
    }

    pub fn getRecentAverageFPS(self: *const Profiler) f64 {
        var sum: f32 = 0;
        var count: usize = 0;
        for (self.frame_history) |t| {
            if (t > 0) {
                sum += t;
                count += 1;
            }
        }
        if (count == 0 or sum == 0) return 0;
        return 1000.0 / (@as(f64, sum) / @as(f64, @floatFromInt(count)));
    }

    pub fn updateSceneStats(self: *Profiler, spheres: usize, triangles: usize, bvh_nodes: usize) void {
        self.sphere_count = spheres;
        self.triangle_count = triangles;
        self.bvh_node_count = bvh_nodes;

        // Estimate GPU memory (rough)
        const sphere_size = 48; // GPUSphere size
        const triangle_size = 144; // GPUTriangle size
        const bvh_node_size = 32; // GPUBVHNode size

        self.gpu_memory_used = spheres * sphere_size + triangles * triangle_size + bvh_nodes * bvh_node_size;
    }

    pub fn updateRenderStats(self: *Profiler, samples: u32, width: u32, height: u32, depth: u32) void {
        self.samples_accumulated = samples;
        self.rays_per_frame = @as(u64, width) * @as(u64, height) * @as(u64, depth);
    }

    pub fn reset(self: *Profiler) void {
        self.frame_count = 0;
        self.total_time = 0;
        self.min_frame_time = std.math.floatMax(f64);
        self.max_frame_time = 0;
        self.history_index = 0;
        @memset(&self.frame_history, 0);
    }

    pub fn getFrameHistory(self: *const Profiler) []const f32 {
        return &self.frame_history;
    }

    pub fn formatStats(self: *const Profiler, buf: []u8) []const u8 {
        return std.fmt.bufPrint(buf,
            \\PROFILER
            \\--------
            \\FPS: {d:.1} (avg: {d:.1})
            \\Frame: {d:.2}ms (min: {d:.2}, max: {d:.2})
            \\
            \\SCENE
            \\-----
            \\Spheres: {}
            \\Triangles: {}
            \\BVH Nodes: {}
            \\GPU Memory: {d:.2} MB
            \\
            \\RENDER
            \\------
            \\Samples: {}
            \\Rays/frame: {}M
        , .{
            self.getRecentAverageFPS(),
            self.getAverageFPS(),
            self.getSectionTime(.frame_total),
            self.min_frame_time,
            self.max_frame_time,
            self.sphere_count,
            self.triangle_count,
            self.bvh_node_count,
            @as(f64, @floatFromInt(self.gpu_memory_used)) / (1024 * 1024),
            self.samples_accumulated,
            self.rays_per_frame / 1_000_000,
        }) catch "Error formatting stats";
    }
};

// Global profiler instance
pub var global: Profiler = Profiler.init();

// Convenience functions
pub fn start(section: TimingSection) void {
    global.startSection(section);
}

pub fn end(section: TimingSection) void {
    global.endSection(section);
}

pub fn frame() void {
    global.endFrame();
}
