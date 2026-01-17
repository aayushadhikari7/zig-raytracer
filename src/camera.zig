const std = @import("std");
const math = std.math;
const vec3 = @import("vec3.zig");
const ray_mod = @import("ray.zig");

const Vec3 = vec3.Vec3;
const Ray = ray_mod.Ray;

pub const Camera = struct {
    // Camera position and orientation
    position: Vec3,
    yaw: f32, // Horizontal rotation (radians)
    pitch: f32, // Vertical rotation (radians)

    // Lens properties
    defocus_angle: f32, // Variation angle of rays through each pixel
    focus_dist: f32, // Distance from camera to plane of perfect focus

    // Calculated vectors
    front: Vec3,
    right: Vec3,
    up: Vec3,

    // Viewport
    viewport_u: Vec3,
    viewport_v: Vec3,
    pixel_delta_u: Vec3,
    pixel_delta_v: Vec3,
    pixel00_loc: Vec3,

    // Defocus disk
    defocus_disk_u: Vec3,
    defocus_disk_v: Vec3,

    // Image dimensions
    image_width: u32,
    image_height: u32,
    aspect_ratio: f32,
    vfov: f32,

    const world_up = Vec3.init(0, 1, 0);

    pub fn init(
        position: Vec3,
        yaw: f32,
        pitch: f32,
        vfov: f32,
        aspect_ratio: f32,
        image_width: u32,
        defocus_angle: f32,
        focus_dist: f32,
    ) Camera {
        var cam: Camera = undefined;
        cam.position = position;
        cam.yaw = yaw;
        cam.pitch = pitch;
        cam.vfov = vfov;
        cam.aspect_ratio = aspect_ratio;
        cam.image_width = image_width;
        cam.image_height = @intFromFloat(@as(f32, @floatFromInt(image_width)) / aspect_ratio);
        if (cam.image_height < 1) cam.image_height = 1;
        cam.defocus_angle = defocus_angle;
        cam.focus_dist = focus_dist;

        cam.updateVectors();
        return cam;
    }

    pub fn updateVectors(self: *Camera) void {
        // Calculate front vector from yaw and pitch
        self.front = Vec3.init(
            @cos(self.yaw) * @cos(self.pitch),
            @sin(self.pitch),
            @sin(self.yaw) * @cos(self.pitch),
        ).normalize();

        // Calculate right and up vectors
        self.right = self.front.cross(world_up).normalize();
        self.up = self.right.cross(self.front).normalize();

        // Viewport dimensions
        const theta = self.vfov * math.pi / 180.0;
        const h = @tan(theta / 2.0);
        const viewport_height = 2.0 * h * self.focus_dist;
        const viewport_width = viewport_height * (@as(f32, @floatFromInt(self.image_width)) / @as(f32, @floatFromInt(self.image_height)));

        // Viewport edge vectors
        self.viewport_u = self.right.scale(viewport_width);
        self.viewport_v = self.up.scale(-viewport_height);

        // Pixel delta vectors
        self.pixel_delta_u = self.viewport_u.div(@floatFromInt(self.image_width));
        self.pixel_delta_v = self.viewport_v.div(@floatFromInt(self.image_height));

        // Upper left pixel location
        const viewport_upper_left = self.position
            .add(self.front.scale(self.focus_dist))
            .sub(self.viewport_u.div(2))
            .sub(self.viewport_v.div(2));
        self.pixel00_loc = viewport_upper_left
            .add(self.pixel_delta_u.scale(0.5))
            .add(self.pixel_delta_v.scale(0.5));

        // Defocus disk basis vectors
        const defocus_radius = self.focus_dist * @tan((self.defocus_angle / 2.0) * math.pi / 180.0);
        self.defocus_disk_u = self.right.scale(defocus_radius);
        self.defocus_disk_v = self.up.scale(defocus_radius);
    }

    pub fn getRay(self: Camera, i: u32, j: u32, rng: *std.Random) Ray {
        const offset = sampleSquare(rng);
        const pixel_sample = self.pixel00_loc
            .add(self.pixel_delta_u.scale(@as(f32, @floatFromInt(i)) + offset.x))
            .add(self.pixel_delta_v.scale(@as(f32, @floatFromInt(j)) + offset.y));

        const ray_origin = if (self.defocus_angle <= 0)
            self.position
        else
            self.defocusDiskSample(rng);

        const ray_direction = pixel_sample.sub(ray_origin);

        return Ray.init(ray_origin, ray_direction);
    }

    fn sampleSquare(rng: *std.Random) Vec3 {
        return Vec3.init(
            rng.float(f32) - 0.5,
            rng.float(f32) - 0.5,
            0,
        );
    }

    fn defocusDiskSample(self: Camera, rng: *std.Random) Vec3 {
        const p = vec3.randomInUnitDisk(rng);
        return self.position
            .add(self.defocus_disk_u.scale(p.x))
            .add(self.defocus_disk_v.scale(p.y));
    }

    // Movement functions
    pub fn moveForward(self: *Camera, delta: f32) void {
        self.position = self.position.add(self.front.scale(delta));
        self.updateVectors();
    }

    pub fn moveRight(self: *Camera, delta: f32) void {
        self.position = self.position.add(self.right.scale(delta));
        self.updateVectors();
    }

    pub fn moveUp(self: *Camera, delta: f32) void {
        self.position = self.position.add(world_up.scale(delta));
        self.updateVectors();
    }

    pub fn rotate(self: *Camera, yaw_delta: f32, pitch_delta: f32) void {
        self.yaw += yaw_delta;
        self.pitch += pitch_delta;

        // Clamp pitch to avoid gimbal lock
        const max_pitch = 89.0 * math.pi / 180.0;
        self.pitch = @max(-max_pitch, @min(max_pitch, self.pitch));

        self.updateVectors();
    }
};
