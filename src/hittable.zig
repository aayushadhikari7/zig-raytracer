const std = @import("std");
const vec3 = @import("vec3.zig");
const ray_mod = @import("ray.zig");
const material_mod = @import("material.zig");

const Vec3 = vec3.Vec3;
const Ray = ray_mod.Ray;
const Material = material_mod.Material;

pub const HitRecord = struct {
    point: Vec3,
    normal: Vec3,
    t: f32,
    front_face: bool,
    material: Material,

    pub fn setFaceNormal(self: *HitRecord, r: Ray, outward_normal: Vec3) void {
        self.front_face = r.direction.dot(outward_normal) < 0;
        self.normal = if (self.front_face) outward_normal else outward_normal.negate();
    }
};

pub const Sphere = struct {
    center: Vec3,
    radius: f32,
    material: Material,

    pub fn init(center: Vec3, radius: f32, material: Material) Sphere {
        return .{ .center = center, .radius = radius, .material = material };
    }

    pub fn hit(self: Sphere, r: Ray, ray_tmin: f32, ray_tmax: f32) ?HitRecord {
        const oc = self.center.sub(r.origin);
        const a = r.direction.lengthSquared();
        const h = r.direction.dot(oc);
        const c = oc.lengthSquared() - self.radius * self.radius;
        const discriminant = h * h - a * c;

        if (discriminant < 0) return null;

        const sqrtd = @sqrt(discriminant);

        // Find the nearest root in acceptable range
        var root = (h - sqrtd) / a;
        if (root <= ray_tmin or ray_tmax <= root) {
            root = (h + sqrtd) / a;
            if (root <= ray_tmin or ray_tmax <= root) {
                return null;
            }
        }

        var rec: HitRecord = undefined;
        rec.t = root;
        rec.point = r.at(rec.t);
        const outward_normal = rec.point.sub(self.center).div(self.radius);
        rec.setFaceNormal(r, outward_normal);
        rec.material = self.material;

        return rec;
    }
};

pub const World = struct {
    spheres: std.ArrayList(Sphere),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) World {
        return .{
            .spheres = .empty,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *World) void {
        self.spheres.deinit(self.allocator);
    }

    pub fn add(self: *World, sphere: Sphere) !void {
        try self.spheres.append(self.allocator, sphere);
    }

    pub fn hit(self: World, r: Ray, ray_tmin: f32, ray_tmax: f32) ?HitRecord {
        var closest_so_far = ray_tmax;
        var hit_record: ?HitRecord = null;

        for (self.spheres.items) |sphere| {
            if (sphere.hit(r, ray_tmin, closest_so_far)) |rec| {
                closest_so_far = rec.t;
                hit_record = rec;
            }
        }

        return hit_record;
    }

    pub fn clear(self: *World) void {
        self.spheres.clearRetainingCapacity();
    }
};
