const std = @import("std");
const math = std.math;

pub const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub const zero = Vec3{ .x = 0, .y = 0, .z = 0 };
    pub const one = Vec3{ .x = 1, .y = 1, .z = 1 };

    pub fn init(x: f32, y: f32, z: f32) Vec3 {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn add(self: Vec3, other: Vec3) Vec3 {
        return .{ .x = self.x + other.x, .y = self.y + other.y, .z = self.z + other.z };
    }

    pub fn sub(self: Vec3, other: Vec3) Vec3 {
        return .{ .x = self.x - other.x, .y = self.y - other.y, .z = self.z - other.z };
    }

    pub fn mul(self: Vec3, other: Vec3) Vec3 {
        return .{ .x = self.x * other.x, .y = self.y * other.y, .z = self.z * other.z };
    }

    pub fn scale(self: Vec3, t: f32) Vec3 {
        return .{ .x = self.x * t, .y = self.y * t, .z = self.z * t };
    }

    pub fn div(self: Vec3, t: f32) Vec3 {
        return self.scale(1.0 / t);
    }

    pub fn dot(self: Vec3, other: Vec3) f32 {
        return self.x * other.x + self.y * other.y + self.z * other.z;
    }

    pub fn cross(self: Vec3, other: Vec3) Vec3 {
        return .{
            .x = self.y * other.z - self.z * other.y,
            .y = self.z * other.x - self.x * other.z,
            .z = self.x * other.y - self.y * other.x,
        };
    }

    pub fn length(self: Vec3) f32 {
        return @sqrt(self.lengthSquared());
    }

    pub fn lengthSquared(self: Vec3) f32 {
        return self.dot(self);
    }

    pub fn normalize(self: Vec3) Vec3 {
        const len = self.length();
        if (len == 0) return Vec3.zero;
        return self.div(len);
    }

    pub fn negate(self: Vec3) Vec3 {
        return .{ .x = -self.x, .y = -self.y, .z = -self.z };
    }

    pub fn reflect(self: Vec3, normal: Vec3) Vec3 {
        return self.sub(normal.scale(2.0 * self.dot(normal)));
    }

    pub fn refract(self: Vec3, normal: Vec3, etai_over_etat: f32) Vec3 {
        const cos_theta = @min(self.negate().dot(normal), 1.0);
        const r_out_perp = self.add(normal.scale(cos_theta)).scale(etai_over_etat);
        const r_out_parallel = normal.scale(-@sqrt(@abs(1.0 - r_out_perp.lengthSquared())));
        return r_out_perp.add(r_out_parallel);
    }

    pub fn nearZero(self: Vec3) bool {
        const s = 1e-8;
        return (@abs(self.x) < s) and (@abs(self.y) < s) and (@abs(self.z) < s);
    }

    pub fn lerp(a: Vec3, b: Vec3, t: f32) Vec3 {
        return a.scale(1.0 - t).add(b.scale(t));
    }
};

// Color is just an alias for Vec3 (r, g, b)
pub const Color = Vec3;

pub fn randomFloat(rng: *std.Random) f32 {
    return rng.float(f32);
}

pub fn randomFloatRange(rng: *std.Random, min: f32, max: f32) f32 {
    return min + (max - min) * rng.float(f32);
}

pub fn randomVec3(rng: *std.Random) Vec3 {
    return Vec3.init(randomFloat(rng), randomFloat(rng), randomFloat(rng));
}

pub fn randomVec3Range(rng: *std.Random, min: f32, max: f32) Vec3 {
    return Vec3.init(
        randomFloatRange(rng, min, max),
        randomFloatRange(rng, min, max),
        randomFloatRange(rng, min, max),
    );
}

pub fn randomInUnitSphere(rng: *std.Random) Vec3 {
    while (true) {
        const p = randomVec3Range(rng, -1, 1);
        if (p.lengthSquared() < 1) return p;
    }
}

pub fn randomUnitVector(rng: *std.Random) Vec3 {
    return randomInUnitSphere(rng).normalize();
}

pub fn randomInUnitDisk(rng: *std.Random) Vec3 {
    while (true) {
        const p = Vec3.init(randomFloatRange(rng, -1, 1), randomFloatRange(rng, -1, 1), 0);
        if (p.lengthSquared() < 1) return p;
    }
}

pub fn randomOnHemisphere(rng: *std.Random, normal: Vec3) Vec3 {
    const on_unit_sphere = randomUnitVector(rng);
    if (on_unit_sphere.dot(normal) > 0.0) {
        return on_unit_sphere;
    } else {
        return on_unit_sphere.negate();
    }
}
