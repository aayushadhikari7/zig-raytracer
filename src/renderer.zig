const std = @import("std");
const vec3 = @import("vec3.zig");
const ray_mod = @import("ray.zig");
const hittable = @import("hittable.zig");
const camera_mod = @import("camera.zig");

const Vec3 = vec3.Vec3;
const Color = vec3.Color;
const Ray = ray_mod.Ray;
const World = hittable.World;
const Camera = camera_mod.Camera;

pub const Renderer = struct {
    // Render settings
    max_depth: u32,
    samples_per_pixel: u32,

    // Accumulation buffer for progressive rendering
    accumulator: []Vec3,
    sample_count: u32,
    width: u32,
    height: u32,

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !Renderer {
        const size = width * height;
        const accumulator = try allocator.alloc(Vec3, size);
        @memset(accumulator, Vec3.zero);

        return .{
            .max_depth = 10,
            .samples_per_pixel = 1, // Per frame, accumulates over time
            .accumulator = accumulator,
            .sample_count = 0,
            .width = width,
            .height = height,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Renderer) void {
        self.allocator.free(self.accumulator);
    }

    pub fn reset(self: *Renderer) void {
        @memset(self.accumulator, Vec3.zero);
        self.sample_count = 0;
    }

    pub fn resize(self: *Renderer, width: u32, height: u32) !void {
        if (width == self.width and height == self.height) return;

        self.allocator.free(self.accumulator);
        const size = width * height;
        self.accumulator = try self.allocator.alloc(Vec3, size);
        @memset(self.accumulator, Vec3.zero);
        self.width = width;
        self.height = height;
        self.sample_count = 0;
    }

    pub fn render(self: *Renderer, camera: *const Camera, world: *const World, pixels: []u8) void {
        self.sample_count += 1;
        const inv_samples = 1.0 / @as(f32, @floatFromInt(self.sample_count));

        // Parallel rendering using Zig's thread pool would go here
        // For simplicity, single-threaded first
        var prng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
        var rng = prng.random();

        for (0..self.height) |j| {
            for (0..self.width) |i| {
                const idx = j * self.width + i;
                const ray = camera.getRay(@intCast(i), @intCast(j), &rng);
                const color = rayColor(ray, world, self.max_depth, &rng);

                // Accumulate
                self.accumulator[idx] = self.accumulator[idx].add(color);

                // Convert to output pixel
                const averaged = self.accumulator[idx].scale(inv_samples);
                const pixel_idx = idx * 4;

                // Gamma correction (gamma = 2.0)
                pixels[pixel_idx + 0] = linearToGamma(averaged.x);
                pixels[pixel_idx + 1] = linearToGamma(averaged.y);
                pixels[pixel_idx + 2] = linearToGamma(averaged.z);
                pixels[pixel_idx + 3] = 255;
            }
        }
    }

    pub fn getSampleCount(self: *const Renderer) u32 {
        return self.sample_count;
    }
};

fn rayColor(r: Ray, world: *const World, depth: u32, rng: *std.Random) Color {
    if (depth == 0) return Color.zero;

    if (world.hit(r, 0.001, std.math.inf(f32))) |rec| {
        if (rec.material.scatter(r, rec.point, rec.normal, rec.front_face, rng)) |result| {
            return result.attenuation.mul(rayColor(result.scattered, world, depth - 1, rng));
        }
        return Color.zero;
    }

    // Sky gradient
    const unit_direction = r.direction.normalize();
    const a = 0.5 * (unit_direction.y + 1.0);
    return Color.init(1.0, 1.0, 1.0).scale(1.0 - a).add(Color.init(0.5, 0.7, 1.0).scale(a));
}

fn linearToGamma(linear: f32) u8 {
    const gamma = if (linear > 0) @sqrt(linear) else 0;
    const clamped = @max(0.0, @min(0.999, gamma));
    return @intFromFloat(256.0 * clamped);
}
