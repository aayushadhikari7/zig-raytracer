const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;

pub const Ray = struct {
    origin: Vec3,
    direction: Vec3,

    pub fn init(origin: Vec3, direction: Vec3) Ray {
        return .{ .origin = origin, .direction = direction };
    }

    pub fn at(self: Ray, t: f32) Vec3 {
        return self.origin.add(self.direction.scale(t));
    }
};
