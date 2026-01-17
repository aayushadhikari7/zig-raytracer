const std = @import("std");
const vec3 = @import("vec3.zig");
const ray_mod = @import("ray.zig");

const Vec3 = vec3.Vec3;
const Color = vec3.Color;
const Ray = ray_mod.Ray;

pub const MaterialType = enum {
    lambertian,
    metal,
    dielectric,
};

pub const Material = struct {
    type: MaterialType,
    albedo: Color,
    fuzz: f32, // For metal
    ior: f32, // Index of refraction for dielectric

    pub fn lambertian(albedo: Color) Material {
        return .{
            .type = .lambertian,
            .albedo = albedo,
            .fuzz = 0,
            .ior = 1,
        };
    }

    pub fn metal(albedo: Color, fuzz: f32) Material {
        return .{
            .type = .metal,
            .albedo = albedo,
            .fuzz = if (fuzz < 1) fuzz else 1,
            .ior = 1,
        };
    }

    pub fn dielectric(ior: f32) Material {
        return .{
            .type = .dielectric,
            .albedo = Color.init(1, 1, 1),
            .fuzz = 0,
            .ior = ior,
        };
    }

    pub fn scatter(
        self: Material,
        r_in: Ray,
        hit_point: Vec3,
        hit_normal: Vec3,
        front_face: bool,
        rng: *std.Random,
    ) ?struct { scattered: Ray, attenuation: Color } {
        switch (self.type) {
            .lambertian => {
                var scatter_direction = hit_normal.add(vec3.randomUnitVector(rng));
                if (scatter_direction.nearZero()) {
                    scatter_direction = hit_normal;
                }
                return .{
                    .scattered = Ray.init(hit_point, scatter_direction),
                    .attenuation = self.albedo,
                };
            },
            .metal => {
                var reflected = r_in.direction.normalize().reflect(hit_normal);
                reflected = reflected.add(vec3.randomUnitVector(rng).scale(self.fuzz));
                if (reflected.dot(hit_normal) > 0) {
                    return .{
                        .scattered = Ray.init(hit_point, reflected),
                        .attenuation = self.albedo,
                    };
                }
                return null;
            },
            .dielectric => {
                const ri = if (front_face) (1.0 / self.ior) else self.ior;
                const unit_direction = r_in.direction.normalize();
                const cos_theta = @min(unit_direction.negate().dot(hit_normal), 1.0);
                const sin_theta = @sqrt(1.0 - cos_theta * cos_theta);

                const cannot_refract = ri * sin_theta > 1.0;
                const direction = if (cannot_refract or reflectance(cos_theta, ri) > vec3.randomFloat(rng))
                    unit_direction.reflect(hit_normal)
                else
                    unit_direction.refract(hit_normal, ri);

                return .{
                    .scattered = Ray.init(hit_point, direction),
                    .attenuation = self.albedo,
                };
            },
        }
    }
};

fn reflectance(cosine: f32, ref_idx: f32) f32 {
    // Schlick's approximation
    var r0 = (1 - ref_idx) / (1 + ref_idx);
    r0 = r0 * r0;
    return r0 + (1 - r0) * std.math.pow(f32, 1 - cosine, 5);
}
