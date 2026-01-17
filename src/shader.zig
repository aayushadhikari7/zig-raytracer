// ============================================================================
// COMPUTE SHADER MODULE - GPU path tracing shader
// ============================================================================

pub const compute_shader_source: [*:0]const u8 =
    \\#version 430 core
    \\layout(local_size_x = 16, local_size_y = 16) in;
    \\layout(rgba32f, binding = 0) uniform image2D outputImage;
    \\layout(rgba32f, binding = 1) uniform image2D accumImage;
    \\
    \\uniform vec3 u_camera_pos;
    \\uniform vec3 u_camera_forward;
    \\uniform vec3 u_camera_right;
    \\uniform vec3 u_camera_up;
    \\uniform vec3 u_prev_camera_pos;
    \\uniform vec3 u_prev_camera_forward;
    \\uniform float u_fov_scale;
    \\uniform float u_aperture;
    \\uniform float u_focus_dist;
    \\uniform uint u_frame;
    \\uniform uint u_sample;
    \\uniform int u_width;
    \\uniform int u_height;
    \\uniform float u_aspect;
    \\
    \\// Effect controls
    \\uniform float u_chromatic;
    \\uniform float u_motion_blur;
    \\uniform float u_bloom;
    \\uniform float u_nee;
    \\uniform float u_roughness_mult;
    \\uniform float u_exposure;
    \\uniform float u_vignette;
    \\uniform float u_normal_strength;
    \\uniform float u_displacement;  // Displacement/parallax strength
    \\uniform float u_denoise;
    \\uniform float u_fog_density;
    \\uniform vec3 u_fog_color;
    \\uniform float u_film_grain;
    \\uniform float u_dispersion;  // Glass dispersion strength
    \\uniform float u_lens_flare;  // Lens flare strength
    \\uniform float u_iridescence; // Thin-film iridescence
    \\uniform float u_anisotropy;  // Anisotropic reflection (brushed metal)
    \\uniform float u_color_temp;  // Color temperature (-1 cool, +1 warm)
    \\uniform float u_saturation;  // Saturation multiplier
    \\uniform float u_scanlines;   // CRT scanline effect
    \\uniform float u_tilt_shift;  // Tilt-shift miniature effect
    \\uniform float u_glitter;     // Glitter/sparkle intensity
    \\uniform float u_heat_haze;   // Heat haze distortion
    \\// MEGA EFFECTS BATCH 2
    \\uniform float u_kaleidoscope; // Kaleidoscope segments
    \\uniform float u_pixelate;     // Pixelation
    \\uniform float u_edge_detect;  // Edge detection
    \\uniform float u_halftone;     // Halftone dots
    \\uniform float u_night_vision; // Night vision
    \\uniform float u_thermal;      // Thermal vision
    \\uniform float u_underwater;   // Underwater effect
    \\uniform float u_rain_drops;   // Rain on lens
    \\uniform float u_vhs_effect;   // VHS distortion
    \\uniform float u_anaglyph_3d;  // 3D anaglyph
    \\uniform float u_fisheye;      // Fisheye lens
    \\uniform float u_posterize;    // Posterization levels
    \\uniform float u_sepia;        // Sepia filter
    \\uniform float u_frosted;      // Frosted glass
    \\uniform float u_radial_blur;  // Radial blur
    \\uniform float u_dither;       // Dithering
    \\uniform float u_holographic;  // Holographic material
    \\uniform float u_ascii_mode;   // ASCII art mode
    \\
    \\#define MAX_DEPTH 4
    \\#define BVH_STACK_SIZE 48  // Reduced for better performance
    \\
    \\struct Sphere {
    \\    vec3 center;
    \\    float radius;
    \\    vec3 albedo;
    \\    float fuzz;
    \\    float ior;
    \\    float emissive;
    \\    int mat_type;
    \\    float pad;
    \\};
    \\
    \\struct BVHNode {
    \\    vec3 aabb_min;
    \\    int left_child;   // -1 if leaf
    \\    vec3 aabb_max;
    \\    int right_child;  // sphere_idx if leaf
    \\};
    \\
    \\layout(std430, binding = 2) buffer SphereBuffer {
    \\    int num_spheres;
    \\    int pad1, pad2, pad3;
    \\    Sphere spheres[];
    \\};
    \\
    \\layout(std430, binding = 3) buffer BVHBuffer {
    \\    int num_nodes;
    \\    int bvh_pad1, bvh_pad2, bvh_pad3;
    \\    BVHNode nodes[];
    \\};
    \\
    \\struct Triangle {
    \\    vec3 v0;
    \\    int mat_type;
    \\    vec3 v1;
    \\    float pad1;
    \\    vec3 v2;
    \\    float pad2;
    \\    vec3 n0;
    \\    float pad3;
    \\    vec3 n1;
    \\    float pad4;
    \\    vec3 n2;
    \\    float pad5;
    \\    vec3 albedo;
    \\    float emissive;
    \\    vec2 uv0;
    \\    vec2 uv1;
    \\    vec2 uv2;
    \\    int texture_id;
    \\    int pad_uv;
    \\};
    \\
    \\layout(std430, binding = 4) buffer TriangleBuffer {
    \\    int num_triangles;
    \\    int tri_pad1, tri_pad2, tri_pad3;
    \\    Triangle triangles[];
    \\};
    \\
    \\layout(std430, binding = 5) buffer TriBVHBuffer {
    \\    int num_tri_nodes;
    \\    int tri_bvh_pad1, tri_bvh_pad2, tri_bvh_pad3;
    \\    BVHNode tri_nodes[];
    \\};
    \\
    \\// Area light for soft shadows
    \\struct AreaLight {
    \\    vec3 position;   // Corner position
    \\    float pad0;
    \\    vec3 u_vec;      // First edge vector
    \\    float pad1;
    \\    vec3 v_vec;      // Second edge vector
    \\    float pad2;
    \\    vec3 normal;     // Light facing direction
    \\    float area;      // Pre-computed area
    \\    vec3 color;      // Light color
    \\    float intensity; // Light intensity
    \\};
    \\
    \\layout(std430, binding = 6) buffer AreaLightBuffer {
    \\    int num_area_lights;
    \\    int area_pad1, area_pad2, area_pad3;
    \\    AreaLight area_lights[];
    \\};
    \\
    \\// Mesh instance for instanced rendering
    \\struct MeshInstance {
    \\    mat4 transform;        // Model transform matrix
    \\    mat4 inv_transform;    // PRE-COMPUTED inverse (avoids per-ray inversion!)
    \\    vec3 normal_row0;
    \\    int mesh_start;        // Start index in triangle buffer
    \\    vec3 normal_row1;
    \\    int mesh_end;          // End index in triangle buffer
    \\    vec3 normal_row2;
    \\    int mesh_bvh_root;     // Root index into mesh_bvh_nodes (-1 = no BVH, linear search)
    \\};
    \\
    \\layout(std430, binding = 7) buffer InstanceBuffer {
    \\    int num_instances;
    \\    int inst_pad1, inst_pad2, inst_pad3;
    \\    MeshInstance instances[];
    \\};
    \\
    \\layout(std430, binding = 8) buffer InstanceBVHBuffer {
    \\    BVHNode instance_bvh[];
    \\};
    \\
    \\// Per-mesh BVH nodes (object-space BVHs for instanced meshes)
    \\layout(std430, binding = 12) buffer MeshBVHBuffer {
    \\    BVHNode mesh_bvh_nodes[];
    \\};
    \\
    \\uniform int u_instance_bvh_root;
    \\
    \\// CSG primitive - basic shape for CSG operations
    \\struct CSGPrimitive {
    \\    vec3 center;
    \\    int prim_type;  // 0=sphere, 1=box, 2=cylinder, 3=torus
    \\    vec3 size;      // radius for sphere, half-extents for box
    \\    float pad0;
    \\    vec3 rotation;  // euler angles
    \\    float pad1;
    \\};
    \\
    \\// CSG object - combines primitives with boolean operations
    \\struct CSGObject {
    \\    int prim_a;     // First primitive index
    \\    int prim_b;     // Second primitive index
    \\    int operation;  // 0=union, 1=intersect, 2=subtract, 3=smooth_union
    \\    float smooth_k; // Smoothness for smooth ops
    \\    vec3 albedo;
    \\    int mat_type;
    \\    float fuzz;
    \\    float ior;
    \\    float emissive;
    \\    float pad;
    \\};
    \\
    \\layout(std430, binding = 9) buffer CSGPrimitiveBuffer {
    \\    int num_csg_prims;
    \\    int csg_prim_pad1, csg_prim_pad2, csg_prim_pad3;
    \\    CSGPrimitive csg_primitives[];
    \\};
    \\
    \\layout(std430, binding = 10) buffer CSGObjectBuffer {
    \\    int num_csg_objects;
    \\    int csg_obj_pad1, csg_obj_pad2, csg_obj_pad3;
    \\    CSGObject csg_objects[];
    \\};
    \\
    \\uint state;
    \\
    \\uint pcg_hash(uint input) {
    \\    uint s = input * 747796405u + 2891336453u;
    \\    uint word = ((s >> ((s >> 28u) + 4u)) ^ s) * 277803737u;
    \\    return (word >> 22u) ^ word;
    \\}
    \\
    \\float rand() {
    \\    state = pcg_hash(state);
    \\    return float(state) / 4294967295.0;
    \\}
    \\
    \\// Direct formula - NO LOOPS! (was 100-iteration rejection sampling)
    \\vec3 random_unit_vector() {
    \\    float u = rand();
    \\    float v = rand();
    \\    float theta = 2.0 * 3.14159265 * u;
    \\    float phi = acos(2.0 * v - 1.0);
    \\    return vec3(sin(phi) * cos(theta), sin(phi) * sin(theta), cos(phi));
    \\}
    \\
    \\vec3 random_in_unit_sphere() {
    \\    return random_unit_vector() * pow(rand(), 1.0/3.0);
    \\}
    \\
    \\vec3 random_in_unit_disk() {
    \\    float r = sqrt(rand());
    \\    float theta = 2.0 * 3.14159265 * rand();
    \\    return vec3(r * cos(theta), r * sin(theta), 0.0);
    \\}
    \\
    \\// Bokeh shape types: 0=circle, 1=hexagon, 2=star, 3=heart
    \\uniform int u_bokeh_shape;
    \\
    \\// Debug/visualization modes: 0=normal, 1=BVH heatmap, 2=normals, 3=depth
    \\uniform int u_debug_mode;
    \\
    \\// Global intersection counter for BVH visualization
    \\int g_intersection_count = 0;
    \\
    \\// Convert wavelength (380-780nm) to RGB for heatmap visualization
    \\// Based on: https://www.shadertoy.com/view/ls2Bz1
    \\vec3 wavelengthToRGB(float wavelength) {
    \\    float t;
    \\    vec3 rgb;
    \\    if (wavelength >= 380.0 && wavelength < 440.0) {
    \\        t = (wavelength - 380.0) / (440.0 - 380.0);
    \\        rgb = vec3(0.33 - 0.33 * t, 0.0, 1.0);
    \\    } else if (wavelength >= 440.0 && wavelength < 490.0) {
    \\        t = (wavelength - 440.0) / (490.0 - 440.0);
    \\        rgb = vec3(0.0, t, 1.0);
    \\    } else if (wavelength >= 490.0 && wavelength < 510.0) {
    \\        t = (wavelength - 490.0) / (510.0 - 490.0);
    \\        rgb = vec3(0.0, 1.0, 1.0 - t);
    \\    } else if (wavelength >= 510.0 && wavelength < 580.0) {
    \\        t = (wavelength - 510.0) / (580.0 - 510.0);
    \\        rgb = vec3(t, 1.0, 0.0);
    \\    } else if (wavelength >= 580.0 && wavelength < 645.0) {
    \\        t = (wavelength - 580.0) / (645.0 - 580.0);
    \\        rgb = vec3(1.0, 1.0 - t, 0.0);
    \\    } else if (wavelength >= 645.0 && wavelength <= 780.0) {
    \\        rgb = vec3(1.0, 0.0, 0.0);
    \\    } else {
    \\        rgb = vec3(0.0);
    \\    }
    \\    // Apply intensity fade at edges of visible spectrum
    \\    float factor = 1.0;
    \\    if (wavelength >= 380.0 && wavelength < 420.0) {
    \\        factor = 0.3 + 0.7 * (wavelength - 380.0) / (420.0 - 380.0);
    \\    } else if (wavelength >= 700.0 && wavelength <= 780.0) {
    \\        factor = 0.3 + 0.7 * (780.0 - wavelength) / (780.0 - 700.0);
    \\    }
    \\    return rgb * factor;
    \\}
    \\
    \\// Convert intersection count to heatmap color
    \\vec3 intersectionHeatmap(int count) {
    \\    // Map count to wavelength: 0 = blue (480nm), high = red (650nm)
    \\    // Typical scene: 0-100 intersections per ray
    \\    float normalized = clamp(float(count) / 100.0, 0.0, 1.0);
    \\    float wavelength = 480.0 + normalized * 170.0; // Blue to red
    \\    return wavelengthToRGB(wavelength) * 1.5; // Boost brightness
    \\}
    \\
    \\// Sample point in hexagonal aperture
    \\vec2 sample_hexagon(float u, float v) {
    \\    // Convert to polar and map to hexagon
    \\    float angle = u * 6.28318530718;
    \\    float radius = sqrt(v);
    \\
    \\    // Hexagon distance function
    \\    float sector = floor(angle / 1.0471975512);
    \\    float sectorAngle = mod(angle, 1.0471975512) - 0.5235987756;
    \\    float hexRadius = cos(0.5235987756) / cos(sectorAngle);
    \\
    \\    return vec2(cos(angle), sin(angle)) * radius * min(hexRadius, 1.0);
    \\}
    \\
    \\// Sample point in star-shaped aperture (5-pointed)
    \\vec2 sample_star(float u, float v) {
    \\    float angle = u * 6.28318530718;
    \\    float radius = sqrt(v);
    \\
    \\    // Star shape modulation
    \\    float starMod = 0.5 + 0.5 * cos(angle * 5.0);
    \\    float starRadius = 0.5 + 0.5 * starMod;
    \\
    \\    return vec2(cos(angle), sin(angle)) * radius * starRadius;
    \\}
    \\
    \\// Sample point in heart-shaped aperture
    \\vec2 sample_heart(float u, float v) {
    \\    float t = u * 6.28318530718;
    \\    float scale = sqrt(v) * 0.5;
    \\
    \\    // Parametric heart curve
    \\    float x = 16.0 * pow(sin(t), 3.0);
    \\    float y = 13.0 * cos(t) - 5.0 * cos(2.0*t) - 2.0 * cos(3.0*t) - cos(4.0*t);
    \\
    \\    return vec2(x, y) * scale / 16.0;
    \\}
    \\
    \\// Get point in shaped aperture based on current bokeh shape setting
    \\vec3 sample_bokeh_aperture() {
    \\    float u = rand();
    \\    float v = rand();
    \\
    \\    vec2 p;
    \\    if (u_bokeh_shape == 0) {
    \\        // Circle (default)
    \\        return random_in_unit_disk();
    \\    } else if (u_bokeh_shape == 1) {
    \\        // Hexagon
    \\        p = sample_hexagon(u, v);
    \\    } else if (u_bokeh_shape == 2) {
    \\        // Star
    \\        p = sample_star(u, v);
    \\    } else if (u_bokeh_shape == 3) {
    \\        // Heart
    \\        p = sample_heart(u, v);
    \\    } else {
    \\        return random_in_unit_disk();
    \\    }
    \\    return vec3(p, 0.0);
    \\}
    \\
    \\// ============ CSG / SDF Functions ============
    \\
    \\// Rotation matrix from euler angles
    \\mat3 rotationMatrix(vec3 euler) {
    \\    float cx = cos(euler.x), sx = sin(euler.x);
    \\    float cy = cos(euler.y), sy = sin(euler.y);
    \\    float cz = cos(euler.z), sz = sin(euler.z);
    \\    return mat3(
    \\        cy*cz, sx*sy*cz - cx*sz, cx*sy*cz + sx*sz,
    \\        cy*sz, sx*sy*sz + cx*cz, cx*sy*sz - sx*cz,
    \\        -sy, sx*cy, cx*cy
    \\    );
    \\}
    \\
    \\// SDF primitives
    \\float sdf_sphere(vec3 p, float r) {
    \\    return length(p) - r;
    \\}
    \\
    \\float sdf_box(vec3 p, vec3 b) {
    \\    vec3 q = abs(p) - b;
    \\    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
    \\}
    \\
    \\float sdf_cylinder(vec3 p, float r, float h) {
    \\    vec2 d = abs(vec2(length(p.xz), p.y)) - vec2(r, h);
    \\    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
    \\}
    \\
    \\float sdf_torus(vec3 p, vec2 t) {
    \\    vec2 q = vec2(length(p.xz) - t.x, p.y);
    \\    return length(q) - t.y;
    \\}
    \\
    \\// Evaluate SDF for a primitive
    \\float sdf_primitive(vec3 p, int idx) {
    \\    CSGPrimitive prim = csg_primitives[idx];
    \\
    \\    // Transform point to local space
    \\    mat3 rot = rotationMatrix(prim.rotation);
    \\    vec3 local_p = transpose(rot) * (p - prim.center);
    \\
    \\    if (prim.prim_type == 0) {
    \\        return sdf_sphere(local_p, prim.size.x);
    \\    } else if (prim.prim_type == 1) {
    \\        return sdf_box(local_p, prim.size);
    \\    } else if (prim.prim_type == 2) {
    \\        return sdf_cylinder(local_p, prim.size.x, prim.size.y);
    \\    } else if (prim.prim_type == 3) {
    \\        return sdf_torus(local_p, prim.size.xy);
    \\    }
    \\    return 1e10;
    \\}
    \\
    \\// Boolean operations
    \\float op_union(float d1, float d2) {
    \\    return min(d1, d2);
    \\}
    \\
    \\float op_intersect(float d1, float d2) {
    \\    return max(d1, d2);
    \\}
    \\
    \\float op_subtract(float d1, float d2) {
    \\    return max(d1, -d2);
    \\}
    \\
    \\float op_smooth_union(float d1, float d2, float k) {
    \\    float h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
    \\    return mix(d2, d1, h) - k * h * (1.0 - h);
    \\}
    \\
    \\// Evaluate CSG object SDF
    \\float sdf_csg_object(vec3 p, int idx) {
    \\    CSGObject obj = csg_objects[idx];
    \\    float d1 = sdf_primitive(p, obj.prim_a);
    \\    float d2 = sdf_primitive(p, obj.prim_b);
    \\
    \\    if (obj.operation == 0) return op_union(d1, d2);
    \\    if (obj.operation == 1) return op_intersect(d1, d2);
    \\    if (obj.operation == 2) return op_subtract(d1, d2);
    \\    if (obj.operation == 3) return op_smooth_union(d1, d2, obj.smooth_k);
    \\    return d1;
    \\}
    \\
    \\// Calculate CSG normal via gradient (pass d to avoid recomputing)
    \\vec3 csg_normal(vec3 p, int idx, float d) {
    \\    const float eps = 0.001;
    \\    return normalize(vec3(
    \\        sdf_csg_object(p + vec3(eps, 0, 0), idx) - d,
    \\        sdf_csg_object(p + vec3(0, eps, 0), idx) - d,
    \\        sdf_csg_object(p + vec3(0, 0, eps), idx) - d
    \\    ));
    \\}
    \\
    \\// HitRecord struct - must be defined before functions that use it
    \\struct HitRecord {
    \\    vec3 point;
    \\    vec3 normal;
    \\    float t;
    \\    bool front_face;
    \\    int sphere_idx;
    \\    bool is_triangle;
    \\    bool is_csg;
    \\    vec2 uv;
    \\    int texture_id;
    \\};
    \\
    \\// Fast ray-sphere intersection for bounding volume
    \\bool hit_bounding_sphere(vec3 ro, vec3 rd, vec3 center, float radius, float t_max, out float t_enter) {
    \\    vec3 oc = ro - center;
    \\    float a = dot(rd, rd);
    \\    float b = dot(oc, rd);
    \\    float c = dot(oc, oc) - radius * radius;
    \\    float discriminant = b * b - a * c;
    \\    if (discriminant < 0.0) return false;
    \\    float sqrtd = sqrt(discriminant);
    \\    float t = (-b - sqrtd) / a;
    \\    if (t < 0.001) t = (-b + sqrtd) / a;
    \\    if (t < 0.001 || t > t_max) return false;
    \\    t_enter = t;
    \\    return true;
    \\}
    \\
    \\// Compute bounding sphere for CSG object from its primitives
    \\void csg_bounds(int idx, out vec3 center, out float radius) {
    \\    CSGObject obj = csg_objects[idx];
    \\    CSGPrimitive pa = csg_primitives[obj.prim_a];
    \\    CSGPrimitive pb = csg_primitives[obj.prim_b];
    \\    // Conservative bound: average center, sum of radii + distance between centers
    \\    center = (pa.center + pb.center) * 0.5;
    \\    float ra = max(max(pa.size.x, pa.size.y), pa.size.z) * 1.5; // Conservative
    \\    float rb = max(max(pb.size.x, pb.size.y), pb.size.z) * 1.5;
    \\    radius = ra + rb + length(pa.center - pb.center) * 0.5;
    \\}
    \\
    \\// Ray march CSG object (with bounding sphere culling)
    \\bool hit_csg(vec3 ro, vec3 rd, int idx, float t_min, float t_max, out HitRecord rec) {
    \\    // Early out: check bounding sphere first
    \\    vec3 bound_center;
    \\    float bound_radius;
    \\    csg_bounds(idx, bound_center, bound_radius);
    \\    float t_enter;
    \\    if (!hit_bounding_sphere(ro, rd, bound_center, bound_radius, t_max, t_enter)) {
    \\        return false;
    \\    }
    \\
    \\    // Start ray march from bounding sphere entry (or t_min if inside)
    \\    float t = max(t_min, t_enter - 0.01);
    \\    const int MAX_STEPS = 48;  // Reduced from 64
    \\    const float EPSILON = 0.001;
    \\
    \\    for (int i = 0; i < MAX_STEPS && t < t_max; i++) {
    \\        vec3 p = ro + rd * t;
    \\        float d = sdf_csg_object(p, idx);
    \\
    \\        if (abs(d) < EPSILON) {
    \\            CSGObject obj = csg_objects[idx];
    \\            rec.t = t;
    \\            rec.point = p;
    \\            rec.normal = csg_normal(p, idx, d);
    \\            rec.front_face = dot(rd, rec.normal) < 0.0;
    \\            if (!rec.front_face) rec.normal = -rec.normal;
    \\            rec.sphere_idx = idx;
    \\            rec.is_triangle = false;
    \\            rec.is_csg = true;
    \\            rec.uv = vec2(0.5);
    \\            rec.texture_id = 0;
    \\            return true;
    \\        }
    \\        t += max(d, EPSILON * 2.0);  // Slightly larger minimum step
    \\    }
    \\    return false;
    \\}
    \\
    \\// Test all CSG objects
    \\bool hit_csg_objects(vec3 ro, vec3 rd, float t_min, inout float closest, inout HitRecord rec) {
    \\    if (num_csg_objects == 0) return false;
    \\
    \\    bool hit_anything = false;
    \\    HitRecord temp_rec;
    \\
    \\    for (int i = 0; i < num_csg_objects; i++) {
    \\        if (hit_csg(ro, rd, i, t_min, closest, temp_rec)) {
    \\            hit_anything = true;
    \\            closest = temp_rec.t;
    \\            rec = temp_rec;
    \\        }
    \\    }
    \\    return hit_anything;
    \\}
    \\
    \\// Ray-AABB intersection test
    \\bool hit_aabb(vec3 ro, vec3 inv_rd, vec3 box_min, vec3 box_max, float t_max) {
    \\    vec3 t0 = (box_min - ro) * inv_rd;
    \\    vec3 t1 = (box_max - ro) * inv_rd;
    \\    vec3 tmin = min(t0, t1);
    \\    vec3 tmax = max(t0, t1);
    \\    float enter = max(max(tmin.x, tmin.y), tmin.z);
    \\    float exit = min(min(tmax.x, tmax.y), tmax.z);
    \\    return enter <= exit && exit > 0.0 && enter < t_max;
    \\}
    \\
    \\bool hit_sphere(vec3 ro, vec3 rd, int idx, float t_min, float t_max, out HitRecord rec) {
    \\    Sphere s = spheres[idx];
    \\    vec3 oc = ro - s.center;
    \\    float a = dot(rd, rd);
    \\    float half_b = dot(oc, rd);
    \\    float c = dot(oc, oc) - s.radius * s.radius;
    \\    float discriminant = half_b * half_b - a * c;
    \\    if (discriminant < 0.0) return false;
    \\    float sqrtd = sqrt(discriminant);
    \\    float root = (-half_b - sqrtd) / a;
    \\    if (root <= t_min || root >= t_max) {
    \\        root = (-half_b + sqrtd) / a;
    \\        if (root <= t_min || root >= t_max) return false;
    \\    }
    \\    rec.t = root;
    \\    rec.point = ro + rd * root;
    \\    vec3 outward_normal = (rec.point - s.center) / s.radius;
    \\    rec.front_face = dot(rd, outward_normal) < 0.0;
    \\    rec.normal = rec.front_face ? outward_normal : -outward_normal;
    \\    rec.sphere_idx = idx;
    \\    rec.is_triangle = false;
    \\    rec.is_csg = false;
    \\    // Spherical UV mapping
    \\    vec3 p = normalize(rec.point - s.center);
    \\    rec.uv = vec2(0.5 + atan(p.z, p.x) / (2.0 * 3.14159265), 0.5 - asin(p.y) / 3.14159265);
    \\    rec.texture_id = 0;
    \\    return true;
    \\}
    \\
    \\// Möller-Trumbore triangle intersection
    \\bool hit_triangle(vec3 ro, vec3 rd, int idx, float t_min, float t_max, out HitRecord rec) {
    \\    Triangle tri = triangles[idx];
    \\    vec3 edge1 = tri.v1 - tri.v0;
    \\    vec3 edge2 = tri.v2 - tri.v0;
    \\    vec3 h = cross(rd, edge2);
    \\    float a = dot(edge1, h);
    \\
    \\    if (abs(a) < 0.0001) return false;  // Ray parallel to triangle
    \\
    \\    float f = 1.0 / a;
    \\    vec3 s = ro - tri.v0;
    \\    float u = f * dot(s, h);
    \\
    \\    if (u < 0.0 || u > 1.0) return false;
    \\
    \\    vec3 q = cross(s, edge1);
    \\    float v = f * dot(rd, q);
    \\
    \\    if (v < 0.0 || u + v > 1.0) return false;
    \\
    \\    float t = f * dot(edge2, q);
    \\
    \\    if (t <= t_min || t >= t_max) return false;
    \\
    \\    rec.t = t;
    \\    rec.point = ro + rd * t;
    \\
    \\    // Interpolate normal using barycentric coordinates
    \\    float w = 1.0 - u - v;
    \\    vec3 interpolated_normal = normalize(w * tri.n0 + u * tri.n1 + v * tri.n2);
    \\
    \\    rec.front_face = dot(rd, interpolated_normal) < 0.0;
    \\    rec.normal = rec.front_face ? interpolated_normal : -interpolated_normal;
    \\    rec.sphere_idx = idx;  // Reuse for triangle index
    \\    rec.is_triangle = true;
    \\    rec.is_csg = false;
    \\    // Interpolate UV coordinates
    \\    rec.uv = w * tri.uv0 + u * tri.uv1 + v * tri.uv2;
    \\    rec.texture_id = tri.texture_id;
    \\    return true;
    \\}
    \\
    \\// Triangle BVH traversal
    \\bool hit_triangles(vec3 ro, vec3 rd, float t_min, float t_max, inout HitRecord rec, inout float closest) {
    \\    if (num_triangles == 0 || num_tri_nodes == 0) return false;
    \\
    \\    vec3 inv_rd = 1.0 / rd;
    \\    int stack[BVH_STACK_SIZE];
    \\    int stack_ptr = 0;
    \\    stack[stack_ptr++] = 0;
    \\
    \\    bool hit_anything = false;
    \\    HitRecord temp_rec;
    \\
    \\    while (stack_ptr > 0) {
    \\        int node_idx = stack[--stack_ptr];
    \\        BVHNode node = tri_nodes[node_idx];
    \\
    \\        if (!hit_aabb(ro, inv_rd, node.aabb_min, node.aabb_max, closest)) {
    \\            continue;
    \\        }
    \\
    \\        if (node.left_child == -1) {
    \\            // Leaf node - test triangle
    \\            int tri_idx = node.right_child;
    \\            if (hit_triangle(ro, rd, tri_idx, t_min, closest, temp_rec)) {
    \\                hit_anything = true;
    \\                closest = temp_rec.t;
    \\                rec = temp_rec;
    \\            }
    \\        } else {
    \\            // Interior node - push children
    \\            if (stack_ptr < BVH_STACK_SIZE - 1) {
    \\                stack[stack_ptr++] = node.right_child;
    \\                stack[stack_ptr++] = node.left_child;
    \\            }
    \\        }
    \\    }
    \\
    \\    return hit_anything;
    \\}
    \\
    \\// Test triangles in a specific range using BVH (for instanced meshes)
    \\bool hit_triangles_range(vec3 ro, vec3 rd, int start_idx, int end_idx, int bvh_root, float t_min, inout float closest, inout HitRecord rec) {
    \\    // If we have a mesh BVH, use it for O(log n) traversal
    \\    if (bvh_root >= 0) {
    \\        vec3 inv_rd = 1.0 / rd;
    \\        int stack[BVH_STACK_SIZE];
    \\        int stack_ptr = 0;
    \\        stack[stack_ptr++] = bvh_root;
    \\
    \\        bool hit_anything = false;
    \\        HitRecord temp_rec;
    \\
    \\        while (stack_ptr > 0) {
    \\            int node_idx = stack[--stack_ptr];
    \\            BVHNode node = mesh_bvh_nodes[node_idx];
    \\
    \\            if (!hit_aabb(ro, inv_rd, node.aabb_min, node.aabb_max, closest)) {
    \\                continue;
    \\            }
    \\
    \\            if (node.left_child == -1) {
    \\                // Leaf node - test triangle (index is relative to mesh start)
    \\                int tri_idx = start_idx + node.right_child;
    \\                if (hit_triangle(ro, rd, tri_idx, t_min, closest, temp_rec)) {
    \\                    hit_anything = true;
    \\                    closest = temp_rec.t;
    \\                    rec = temp_rec;
    \\                }
    \\            } else {
    \\                // Interior node - push children
    \\                if (stack_ptr < BVH_STACK_SIZE - 1) {
    \\                    stack[stack_ptr++] = node.right_child;
    \\                    stack[stack_ptr++] = node.left_child;
    \\                }
    \\            }
    \\        }
    \\        return hit_anything;
    \\    }
    \\
    \\    // Fallback: linear search if no BVH (should rarely happen)
    \\    bool hit_anything = false;
    \\    HitRecord temp_rec;
    \\    for (int i = start_idx; i < end_idx && i < num_triangles; i++) {
    \\        if (hit_triangle(ro, rd, i, t_min, closest, temp_rec)) {
    \\            hit_anything = true;
    \\            closest = temp_rec.t;
    \\            rec = temp_rec;
    \\        }
    \\    }
    \\    return hit_anything;
    \\}
    \\
    \\// Matrix inverse for 4x4 (for ray transformation)
    \\mat4 inverse_mat4(mat4 m) {
    \\    float a00 = m[0][0], a01 = m[0][1], a02 = m[0][2], a03 = m[0][3];
    \\    float a10 = m[1][0], a11 = m[1][1], a12 = m[1][2], a13 = m[1][3];
    \\    float a20 = m[2][0], a21 = m[2][1], a22 = m[2][2], a23 = m[2][3];
    \\    float a30 = m[3][0], a31 = m[3][1], a32 = m[3][2], a33 = m[3][3];
    \\
    \\    float b00 = a00 * a11 - a01 * a10;
    \\    float b01 = a00 * a12 - a02 * a10;
    \\    float b02 = a00 * a13 - a03 * a10;
    \\    float b03 = a01 * a12 - a02 * a11;
    \\    float b04 = a01 * a13 - a03 * a11;
    \\    float b05 = a02 * a13 - a03 * a12;
    \\    float b06 = a20 * a31 - a21 * a30;
    \\    float b07 = a20 * a32 - a22 * a30;
    \\    float b08 = a20 * a33 - a23 * a30;
    \\    float b09 = a21 * a32 - a22 * a31;
    \\    float b10 = a21 * a33 - a23 * a31;
    \\    float b11 = a22 * a33 - a23 * a32;
    \\
    \\    float det = b00 * b11 - b01 * b10 + b02 * b09 + b03 * b08 - b04 * b07 + b05 * b06;
    \\    if (abs(det) < 0.00001) return mat4(1.0);
    \\
    \\    float inv_det = 1.0 / det;
    \\
    \\    return mat4(
    \\        (a11 * b11 - a12 * b10 + a13 * b09) * inv_det,
    \\        (a02 * b10 - a01 * b11 - a03 * b09) * inv_det,
    \\        (a31 * b05 - a32 * b04 + a33 * b03) * inv_det,
    \\        (a22 * b04 - a21 * b05 - a23 * b03) * inv_det,
    \\        (a12 * b08 - a10 * b11 - a13 * b07) * inv_det,
    \\        (a00 * b11 - a02 * b08 + a03 * b07) * inv_det,
    \\        (a32 * b02 - a30 * b05 - a33 * b01) * inv_det,
    \\        (a20 * b05 - a22 * b02 + a23 * b01) * inv_det,
    \\        (a10 * b10 - a11 * b08 + a13 * b06) * inv_det,
    \\        (a01 * b08 - a00 * b10 - a03 * b06) * inv_det,
    \\        (a30 * b04 - a31 * b02 + a33 * b00) * inv_det,
    \\        (a21 * b02 - a20 * b04 - a23 * b00) * inv_det,
    \\        (a11 * b07 - a10 * b09 - a12 * b06) * inv_det,
    \\        (a00 * b09 - a01 * b07 + a02 * b06) * inv_det,
    \\        (a31 * b01 - a30 * b03 - a32 * b00) * inv_det,
    \\        (a20 * b03 - a21 * b01 + a22 * b00) * inv_det
    \\    );
    \\}
    \\
    \\// Test a mesh instance
    \\bool hit_instance(vec3 ro, vec3 rd, int inst_idx, float t_min, inout float closest, inout HitRecord rec) {
    \\    MeshInstance inst = instances[inst_idx];
    \\
    \\    // Transform ray to object space (using PRE-COMPUTED inverse!)
    \\    vec3 local_ro = (inst.inv_transform * vec4(ro, 1.0)).xyz;
    \\    vec3 local_rd_unnorm = (inst.inv_transform * vec4(rd, 0.0)).xyz;
    \\    float rd_scale = length(local_rd_unnorm);
    \\    vec3 local_rd = local_rd_unnorm / rd_scale;  // normalize without recomputing
    \\
    \\    float local_closest = closest * rd_scale;
    \\
    \\    HitRecord local_rec;
    \\    if (!hit_triangles_range(local_ro, local_rd, inst.mesh_start, inst.mesh_end, inst.mesh_bvh_root, t_min * rd_scale, local_closest, local_rec)) {
    \\        return false;
    \\    }
    \\
    \\    // Transform hit back to world space
    \\    closest = local_rec.t / rd_scale;
    \\    rec = local_rec;
    \\    rec.t = closest;
    \\    rec.point = (inst.transform * vec4(local_rec.point, 1.0)).xyz;
    \\
    \\    // Transform normal using normal matrix
    \\    mat3 normal_mat = mat3(inst.normal_row0, inst.normal_row1, inst.normal_row2);
    \\    rec.normal = normalize(normal_mat * local_rec.normal);
    \\    rec.front_face = dot(rd, rec.normal) < 0.0;
    \\    if (!rec.front_face) rec.normal = -rec.normal;
    \\
    \\    return true;
    \\}
    \\
    \\// Instance BVH traversal
    \\bool hit_instances(vec3 ro, vec3 rd, float t_min, inout float closest, inout HitRecord rec) {
    \\    if (num_instances == 0) return false;
    \\
    \\    // If no instance BVH, linear search
    \\    if (u_instance_bvh_root < 0) {
    \\        bool hit_anything = false;
    \\        for (int i = 0; i < num_instances; i++) {
    \\            if (hit_instance(ro, rd, i, t_min, closest, rec)) {
    \\                hit_anything = true;
    \\            }
    \\        }
    \\        return hit_anything;
    \\    }
    \\
    \\    // BVH traversal for instances
    \\    vec3 inv_rd = 1.0 / rd;
    \\    int stack[BVH_STACK_SIZE];
    \\    int stack_ptr = 0;
    \\    stack[stack_ptr++] = u_instance_bvh_root;
    \\
    \\    bool hit_anything = false;
    \\
    \\    while (stack_ptr > 0) {
    \\        int node_idx = stack[--stack_ptr];
    \\        BVHNode node = instance_bvh[node_idx];
    \\
    \\        if (!hit_aabb(ro, inv_rd, node.aabb_min, node.aabb_max, closest)) {
    \\            continue;
    \\        }
    \\
    \\        if (node.left_child == -1) {
    \\            // Leaf node - test instance
    \\            if (hit_instance(ro, rd, node.right_child, t_min, closest, rec)) {
    \\                hit_anything = true;
    \\            }
    \\        } else {
    \\            // Interior node
    \\            if (stack_ptr < BVH_STACK_SIZE - 1) {
    \\                stack[stack_ptr++] = node.right_child;
    \\                stack[stack_ptr++] = node.left_child;
    \\            }
    \\        }
    \\    }
    \\
    \\    return hit_anything;
    \\}
    \\
    \\// BVH traversal using stack
    \\bool hit_world_bvh(vec3 ro, vec3 rd, float t_min, float t_max, out HitRecord rec) {
    \\    vec3 inv_rd = 1.0 / rd;
    \\    int stack[BVH_STACK_SIZE];
    \\    int stack_ptr = 0;
    \\    stack[stack_ptr++] = 0; // Start with root
    \\
    \\    bool hit_anything = false;
    \\    float closest = t_max;
    \\    HitRecord temp_rec;
    \\
    \\    while (stack_ptr > 0) {
    \\        int node_idx = stack[--stack_ptr];
    \\        BVHNode node = nodes[node_idx];
    \\        // g_intersection_count++; // Count BVH node visits
    \\
    \\        if (!hit_aabb(ro, inv_rd, node.aabb_min, node.aabb_max, closest)) {
    \\            continue;
    \\        }
    \\
    \\        if (node.left_child == -1) {
    \\            // Leaf node - test sphere
    \\            int sphere_idx = node.right_child;
    \\            // g_intersection_count++; // Count primitive test
    \\            if (hit_sphere(ro, rd, sphere_idx, t_min, closest, temp_rec)) {
    \\                hit_anything = true;
    \\                closest = temp_rec.t;
    \\                rec = temp_rec;
    \\            }
    \\        } else {
    \\            // Interior node - push children
    \\            if (stack_ptr < BVH_STACK_SIZE - 1) {
    \\                stack[stack_ptr++] = node.right_child;
    \\                stack[stack_ptr++] = node.left_child;
    \\            }
    \\        }
    \\    }
    \\
    \\    // DEBUG TEST 6: Enable triangles + instances
    \\    // Also check triangles
    \\    if (hit_triangles(ro, rd, t_min, closest, rec, closest)) {
    \\        hit_anything = true;
    \\    }
    \\
    \\    // Check mesh instances
    \\    if (hit_instances(ro, rd, t_min, closest, rec)) {
    \\        hit_anything = true;
    \\    }
    \\
    \\    // Check CSG objects (with bounding sphere culling)
    \\    if (hit_csg_objects(ro, rd, t_min, closest, rec)) {
    \\        hit_anything = true;
    \\    }
    \\
    \\    return hit_anything;
    \\}
    \\
    \\float reflectance(float cosine, float ior) {
    \\    float r0 = (1.0 - ior) / (1.0 + ior);
    \\    r0 = r0 * r0;
    \\    float x = 1.0 - cosine;
    \\    float x2 = x * x;
    \\    return r0 + (1.0 - r0) * (x2 * x2 * x);  // x^5 without pow()
    \\}
    \\
    \\// ========== GGX/Cook-Torrance BRDF ==========
    \\const float PI = 3.14159265359;
    \\
    \\// GGX Normal Distribution Function
    \\float DistributionGGX(vec3 N, vec3 H, float roughness) {
    \\    float a = roughness * roughness;
    \\    float a2 = a * a;
    \\    float NdotH = max(dot(N, H), 0.0);
    \\    float NdotH2 = NdotH * NdotH;
    \\    float nom = a2;
    \\    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    \\    denom = PI * denom * denom;
    \\    return nom / max(denom, 0.0001);
    \\}
    \\
    \\// Geometry function (Schlick-GGX)
    \\float GeometrySchlickGGX(float NdotV, float roughness) {
    \\    float r = roughness + 1.0;
    \\    float k = (r * r) / 8.0;
    \\    return NdotV / (NdotV * (1.0 - k) + k);
    \\}
    \\
    \\// Smith's geometry function
    \\float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness) {
    \\    float NdotV = max(dot(N, V), 0.0);
    \\    float NdotL = max(dot(N, L), 0.0);
    \\    return GeometrySchlickGGX(NdotV, roughness) * GeometrySchlickGGX(NdotL, roughness);
    \\}
    \\
    \\// Fresnel-Schlick approximation
    \\vec3 FresnelSchlick(float cosTheta, vec3 F0) {
    \\    return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
    \\}
    \\
    \\// Thin-film iridescence - simulates soap bubbles, oil slicks, beetle shells
    \\vec3 thinFilmIridescence(float cosTheta, float thickness) {
    \\    // Approximate thin-film interference using wavelength-dependent phase shift
    \\    float n_film = 1.33; // Refractive index of thin film (like soap)
    \\    float d = thickness * 500.0; // Film thickness in nm (scaled)
    \\
    \\    // Path difference causes interference at different wavelengths
    \\    float phase = 2.0 * n_film * d * cosTheta;
    \\
    \\    // RGB wavelengths approximately: R=650nm, G=550nm, B=450nm
    \\    vec3 wavelengths = vec3(650.0, 550.0, 450.0);
    \\    vec3 interference;
    \\    interference.r = 0.5 + 0.5 * cos(2.0 * PI * phase / wavelengths.r);
    \\    interference.g = 0.5 + 0.5 * cos(2.0 * PI * phase / wavelengths.g);
    \\    interference.b = 0.5 + 0.5 * cos(2.0 * PI * phase / wavelengths.b);
    \\
    \\    return interference;
    \\}
    \\
    \\// Anisotropic GGX for brushed metal
    \\float AnisotropicGGX(vec3 N, vec3 H, vec3 T, vec3 B, float ax, float ay) {
    \\    float NoH = dot(N, H);
    \\    float ToH = dot(T, H);
    \\    float BoH = dot(B, H);
    \\    float d = ToH * ToH / (ax * ax) + BoH * BoH / (ay * ay) + NoH * NoH;
    \\    return 1.0 / (PI * ax * ay * d * d);
    \\}
    \\
    \\// Glitter/sparkle - randomly oriented micro-facets
    \\float glitterSparkle(vec3 pos, vec3 V, vec3 N, float density) {
    \\    // Create random facet orientations based on position
    \\    vec3 cellPos = floor(pos * density);
    \\    float cellHash = fract(sin(dot(cellPos, vec3(12.9898, 78.233, 45.164))) * 43758.5453);
    \\
    \\    // Random facet normal
    \\    float theta = cellHash * 2.0 * PI;
    \\    float phi = fract(cellHash * 7.31) * PI;
    \\    vec3 facetN = vec3(sin(phi) * cos(theta), sin(phi) * sin(theta), cos(phi));
    \\    facetN = normalize(mix(N, facetN, 0.3)); // Blend with surface normal
    \\
    \\    // Sparkle intensity based on view angle to facet
    \\    float sparkle = pow(max(0.0, dot(reflect(-V, facetN), V)), 256.0);
    \\
    \\    // Only some cells sparkle
    \\    sparkle *= step(0.9, cellHash);
    \\
    \\    return sparkle;
    \\}
    \\
    \\// Heat haze distortion
    \\vec2 heatHazeOffset(vec2 uv, float time, float strength) {
    \\    float distort = sin(uv.y * 50.0 + time * 3.0) * cos(uv.x * 30.0 + time * 2.0);
    \\    distort += sin(uv.y * 80.0 - time * 4.0) * 0.5;
    \\    return vec2(distort, distort * 0.5) * strength * 0.01;
    \\}
    \\
    \\// Color temperature adjustment (Kelvin-like)
    \\vec3 adjustColorTemp(vec3 color, float temp) {
    \\    // temp: -1 = cool (blue), +1 = warm (orange)
    \\    vec3 warm = vec3(1.0, 0.9, 0.7);
    \\    vec3 cool = vec3(0.7, 0.85, 1.0);
    \\    vec3 tint = mix(cool, warm, temp * 0.5 + 0.5);
    \\    return color * tint;
    \\}
    \\
    \\// Saturation adjustment
    \\vec3 adjustSaturation(vec3 color, float sat) {
    \\    float luma = dot(color, vec3(0.299, 0.587, 0.114));
    \\    return mix(vec3(luma), color, sat);
    \\}
    \\
    \\// ============ MEGA EFFECTS BATCH 2 HELPER FUNCTIONS ============
    \\
    \\// Kaleidoscope effect - mirror UV around center
    \\vec2 kaleidoscopeUV(vec2 uv, float segments) {
    \\    if (segments < 2.0) return uv;
    \\    vec2 centered = uv - 0.5;
    \\    float angle = atan(centered.y, centered.x);
    \\    float radius = length(centered);
    \\    float segmentAngle = PI * 2.0 / segments;
    \\    angle = mod(angle, segmentAngle);
    \\    if (mod(floor(atan(centered.y, centered.x) / segmentAngle), 2.0) == 1.0) {
    \\        angle = segmentAngle - angle;
    \\    }
    \\    return vec2(cos(angle), sin(angle)) * radius + 0.5;
    \\}
    \\
    \\// Pixelation effect
    \\vec2 pixelateUV(vec2 uv, float pixelSize) {
    \\    if (pixelSize <= 1.0) return uv;
    \\    return floor(uv * pixelSize) / pixelSize;
    \\}
    \\
    \\// Sobel edge detection kernel
    \\float sobelEdge(ivec2 pixel, int w, int h) {
    \\    float gx = 0.0, gy = 0.0;
    \\    int kernelX[9] = int[](-1, 0, 1, -2, 0, 2, -1, 0, 1);
    \\    int kernelY[9] = int[](-1, -2, -1, 0, 0, 0, 1, 2, 1);
    \\    int idx = 0;
    \\    for (int dy = -1; dy <= 1; dy++) {
    \\        for (int dx = -1; dx <= 1; dx++) {
    \\            ivec2 samplePos = clamp(pixel + ivec2(dx, dy), ivec2(0), ivec2(w-1, h-1));
    \\            vec4 samp = imageLoad(accumImage, samplePos);
    \\            float luma = dot(samp.rgb / max(samp.a, 1.0), vec3(0.299, 0.587, 0.114));
    \\            gx += luma * float(kernelX[idx]);
    \\            gy += luma * float(kernelY[idx]);
    \\            idx++;
    \\        }
    \\    }
    \\    return sqrt(gx * gx + gy * gy);
    \\}
    \\
    \\// Halftone dot pattern
    \\float halftonePattern(vec2 uv, float dotSize, float angle) {
    \\    float s = sin(angle), c = cos(angle);
    \\    vec2 rotated = vec2(c * uv.x - s * uv.y, s * uv.x + c * uv.y);
    \\    vec2 grid = fract(rotated * dotSize) - 0.5;
    \\    return length(grid);
    \\}
    \\
    \\// Night vision green effect
    \\vec3 nightVisionEffect(vec3 color, float strength, ivec2 pixel, uint frame) {
    \\    float luma = dot(color, vec3(0.299, 0.587, 0.114));
    \\    vec3 green = vec3(0.1, luma * 1.5, 0.1);
    \\    // Add scanlines
    \\    float scanline = sin(float(pixel.y) * 2.0) * 0.1 + 0.9;
    \\    green *= scanline;
    \\    // Add noise
    \\    float noise = fract(sin(float(pixel.x * 12345 + pixel.y * 67890 + frame)) * 43758.5453);
    \\    green += (noise - 0.5) * 0.15;
    \\    return mix(color, green, strength);
    \\}
    \\
    \\// Thermal vision palette
    \\vec3 thermalPalette(float heat) {
    \\    // Black -> Blue -> Purple -> Red -> Orange -> Yellow -> White
    \\    vec3 colors[7] = vec3[](
    \\        vec3(0.0, 0.0, 0.0),
    \\        vec3(0.0, 0.0, 0.5),
    \\        vec3(0.5, 0.0, 0.5),
    \\        vec3(1.0, 0.0, 0.0),
    \\        vec3(1.0, 0.5, 0.0),
    \\        vec3(1.0, 1.0, 0.0),
    \\        vec3(1.0, 1.0, 1.0)
    \\    );
    \\    float idx = heat * 6.0;
    \\    int i = int(floor(idx));
    \\    float f = fract(idx);
    \\    i = clamp(i, 0, 5);
    \\    return mix(colors[i], colors[i + 1], f);
    \\}
    \\
    \\// Underwater caustics pattern
    \\float causticPattern(vec2 uv, float time) {
    \\    float c1 = sin(uv.x * 10.0 + time) * sin(uv.y * 10.0 + time * 0.7);
    \\    float c2 = sin(uv.x * 15.0 - time * 1.3) * sin(uv.y * 12.0 + time);
    \\    float c3 = sin((uv.x + uv.y) * 8.0 + time * 0.5);
    \\    return (c1 + c2 + c3) * 0.33 + 0.5;
    \\}
    \\
    \\// Rain drop lens distortion
    \\vec2 rainDropOffset(vec2 uv, float time, float strength) {
    \\    vec2 offset = vec2(0.0);
    \\    // Multiple rain drops at different positions
    \\    for (int i = 0; i < 5; i++) {
    \\        float fi = float(i);
    \\        vec2 dropCenter = vec2(
    \\            fract(sin(fi * 127.1) * 43758.5453),
    \\            fract(sin(fi * 269.5) * 43758.5453)
    \\        );
    \\        float dropTime = fract(time * 0.3 + fi * 0.2);
    \\        float dropRadius = 0.05 + dropTime * 0.1;
    \\        float dropStrength = (1.0 - dropTime) * strength;
    \\        float dist = length(uv - dropCenter);
    \\        if (dist < dropRadius) {
    \\            float ripple = sin(dist * 50.0 - time * 5.0) * dropStrength;
    \\            offset += normalize(uv - dropCenter) * ripple * 0.02;
    \\        }
    \\    }
    \\    return offset;
    \\}
    \\
    \\// VHS distortion effect
    \\vec3 vhsEffect(vec3 color, vec2 uv, uint frame, float strength) {
    \\    // Horizontal jitter
    \\    float jitter = sin(uv.y * 100.0 + float(frame) * 0.5) * strength * 0.01;
    \\    // Color bleeding
    \\    vec3 result = color;
    \\    result.r = mix(result.r, result.r * 1.1, strength);
    \\    // Tracking lines
    \\    float tracking = step(0.98, fract(uv.y * 50.0 + float(frame) * 0.1));
    \\    result = mix(result, vec3(1.0), tracking * strength * 0.5);
    \\    // Noise bands
    \\    float noiseBand = step(0.95, sin(uv.y * 200.0 + float(frame)));
    \\    float noise = fract(sin(uv.x * 12345.0 + float(frame)) * 43758.5453);
    \\    result = mix(result, vec3(noise), noiseBand * strength * 0.3);
    \\    return result;
    \\}
    \\
    \\// Fisheye lens distortion
    \\vec2 fisheyeUV(vec2 uv, float strength) {
    \\    vec2 centered = uv - 0.5;
    \\    float r = length(centered);
    \\    float theta = atan(r * strength);
    \\    float newR = theta / (strength + 0.001);
    \\    return centered * (newR / (r + 0.001)) + 0.5;
    \\}
    \\
    \\// Posterization
    \\vec3 posterize(vec3 color, float levels) {
    \\    if (levels < 2.0) return color;
    \\    return floor(color * levels) / (levels - 1.0);
    \\}
    \\
    \\// Sepia tone
    \\vec3 sepiaEffect(vec3 color, float strength) {
    \\    vec3 sepia = vec3(
    \\        dot(color, vec3(0.393, 0.769, 0.189)),
    \\        dot(color, vec3(0.349, 0.686, 0.168)),
    \\        dot(color, vec3(0.272, 0.534, 0.131))
    \\    );
    \\    return mix(color, sepia, strength);
    \\}
    \\
    \\// Frosted glass blur with noise
    \\vec2 frostedOffset(vec2 uv, float strength, uint frame) {
    \\    float noise1 = fract(sin(dot(uv, vec2(12.9898, 78.233)) + float(frame)) * 43758.5453);
    \\    float noise2 = fract(sin(dot(uv, vec2(93.9898, 67.345)) + float(frame)) * 24634.6345);
    \\    return (vec2(noise1, noise2) - 0.5) * strength * 0.05;
    \\}
    \\
    \\// Radial blur / zoom blur
    \\vec2 radialBlurOffset(vec2 uv, float strength, float sampleIdx) {
    \\    vec2 center = vec2(0.5);
    \\    vec2 dir = uv - center;
    \\    return dir * strength * sampleIdx * 0.01;
    \\}
    \\
    \\// Ordered dithering (Bayer matrix 4x4)
    \\float bayerDither(ivec2 pixel) {
    \\    int bayer[16] = int[](
    \\        0, 8, 2, 10,
    \\        12, 4, 14, 6,
    \\        3, 11, 1, 9,
    \\        15, 7, 13, 5
    \\    );
    \\    int idx = (pixel.x % 4) + (pixel.y % 4) * 4;
    \\    return float(bayer[idx]) / 16.0;
    \\}
    \\
    \\// Holographic rainbow effect based on view angle
    \\vec3 holographicColor(vec3 normal, vec3 viewDir, float strength) {
    \\    float angle = dot(normal, viewDir);
    \\    float hue = fract(angle * 2.0 + strength);
    \\    // HSV to RGB
    \\    vec3 rgb = clamp(abs(mod(hue * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
    \\    return rgb;
    \\}
    \\
    \\// ASCII art brightness to character density
    \\float asciiDensity(float brightness) {
    \\    // Map brightness to a pattern density
    \\    // This creates a stepped pattern simulating ASCII characters
    \\    float levels = 10.0;
    \\    return floor(brightness * levels) / levels;
    \\}
    \\
    \\// Sample GGX distribution for importance sampling
    \\vec3 ImportanceSampleGGX(vec2 Xi, vec3 N, float roughness) {
    \\    float a = roughness * roughness;
    \\    float phi = 2.0 * PI * Xi.x;
    \\    float cosTheta = sqrt((1.0 - Xi.y) / (1.0 + (a * a - 1.0) * Xi.y));
    \\    float sinTheta = sqrt(1.0 - cosTheta * cosTheta);
    \\
    \\    // Spherical to cartesian
    \\    vec3 H = vec3(cos(phi) * sinTheta, sin(phi) * sinTheta, cosTheta);
    \\
    \\    // Tangent space to world space
    \\    vec3 up = abs(N.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
    \\    vec3 tangent = normalize(cross(up, N));
    \\    vec3 bitangent = cross(N, tangent);
    \\
    \\    return normalize(tangent * H.x + bitangent * H.y + N * H.z);
    \\}
    \\
    \\// HDR environment with physically-based atmospheric scattering
    \\vec3 getSky(vec3 rd) {
    \\    // Sun parameters
    \\    vec3 sun_dir = normalize(vec3(0.5, 0.35, -0.7));
    \\    float sun_intensity = 20.0;  // HDR sun intensity
    \\    float sun = max(0.0, dot(rd, sun_dir));
    \\
    \\    // Rayleigh scattering coefficients (blue scatters more)
    \\    vec3 rayleigh = vec3(0.0058, 0.0135, 0.0331);
    \\
    \\    // View angle from horizon
    \\    float mu = rd.y;
    \\    float muS = sun_dir.y;
    \\
    \\    // Optical depth approximation
    \\    float opticalDepth = exp(-max(mu, 0.0) * 4.0);
    \\
    \\    // Sky color with Rayleigh scattering approximation
    \\    vec3 skyColor = vec3(0.3, 0.55, 1.0);  // Zenith blue
    \\    vec3 horizonColor = vec3(0.85, 0.75, 0.65);  // Warm horizon
    \\
    \\    // Blend based on view angle
    \\    float horizonBlend = pow(1.0 - max(mu, 0.0), 3.0);
    \\    vec3 sky = mix(skyColor, horizonColor, horizonBlend);
    \\
    \\    // Add aerial perspective (atmosphere thickness)
    \\    sky *= 1.0 + opticalDepth * 0.3;
    \\
    \\    // Mie scattering for sun halo (forward scattering)
    \\    float miePhase = pow(sun, 4.0) * 0.5;
    \\    sky += vec3(1.0, 0.95, 0.85) * miePhase * 0.4;
    \\
    \\    // Sun disk with HDR intensity
    \\    float sunDisk = smoothstep(0.9997, 0.9999, sun);
    \\    sky += vec3(1.0, 0.98, 0.9) * sunDisk * sun_intensity;
    \\
    \\    // Sun glow/corona
    \\    sky += vec3(1.0, 0.9, 0.7) * pow(sun, 256.0) * 5.0;
    \\    sky += vec3(1.0, 0.85, 0.6) * pow(sun, 32.0) * 0.5;
    \\    sky += vec3(1.0, 0.7, 0.4) * pow(sun, 8.0) * 0.2;
    \\
    \\    // Subtle sunset colors near horizon when looking away from sun
    \\    if (mu < 0.2 && mu > -0.1) {
    \\        float sunsetFactor = (1.0 - abs(dot(normalize(vec3(rd.x, 0.0, rd.z)), normalize(vec3(sun_dir.x, 0.0, sun_dir.z))))) * 0.5;
    \\        sky += vec3(0.4, 0.2, 0.1) * sunsetFactor * (1.0 - smoothstep(-0.1, 0.2, mu));
    \\    }
    \\
    \\    // Ground plane reflection (dark ground below horizon)
    \\    if (mu < 0.0) {
    \\        vec3 groundColor = vec3(0.1, 0.08, 0.06);
    \\        sky = mix(sky, groundColor, smoothstep(0.0, -0.1, mu));
    \\    }
    \\
    \\    return sky;
    \\}
    \\
    \\// ========== Next Event Estimation (Direct Light Sampling) ==========
    \\vec3 sampleLights(vec3 point, vec3 normal, vec3 albedo) {
    \\    vec3 direct = vec3(0.0);
    \\
    \\    // Sample all emissive spheres
    \\    for (int i = 0; i < num_spheres; i++) {
    \\        Sphere light = spheres[i];
    \\        if (light.mat_type != 3) continue;  // Not emissive
    \\
    \\        // Vector to light center
    \\        vec3 toLight = light.center - point;
    \\        float dist2 = dot(toLight, toLight);
    \\        float dist = sqrt(dist2);
    \\        vec3 lightDir = toLight / dist;
    \\
    \\        // Check if light is in front of surface
    \\        float cosTheta = dot(normal, lightDir);
    \\        if (cosTheta <= 0.0) continue;
    \\
    \\        // Sample random point on light sphere
    \\        vec3 randomOffset = random_unit_vector() * light.radius * 0.5;
    \\        vec3 lightPoint = light.center + randomOffset;
    \\        vec3 toSample = lightPoint - point;
    \\        float sampleDist = length(toSample);
    \\        vec3 sampleDir = toSample / sampleDist;
    \\
    \\        // Shadow ray - check occlusion
    \\        HitRecord shadowRec;
    \\        if (hit_world_bvh(point + normal * 0.002, sampleDir, 0.001, sampleDist - 0.01, shadowRec)) {
    \\            // Check if we hit the light itself
    \\            if (shadowRec.sphere_idx != i) continue;  // Occluded by something else
    \\        }
    \\
    \\        // Solid angle of sphere light
    \\        float sinThetaMax = light.radius / dist;
    \\        float cosThetaMax = sqrt(max(0.0, 1.0 - sinThetaMax * sinThetaMax));
    \\        float solidAngle = 2.0 * PI * (1.0 - cosThetaMax);
    \\
    \\        // Lambert BRDF contribution
    \\        float cosThetaSample = max(0.0, dot(normal, sampleDir));
    \\        vec3 lightContrib = albedo * light.albedo * light.emissive;
    \\        direct += lightContrib * cosThetaSample * solidAngle / PI;
    \\    }
    \\
    \\    // Sample rectangular area lights for soft shadows
    \\    for (int i = 0; i < num_area_lights; i++) {
    \\        AreaLight alight = area_lights[i];
    \\
    \\        // Sample random point on the light surface
    \\        float u = rand();
    \\        float v = rand();
    \\        vec3 lightPoint = alight.position + alight.u_vec * u + alight.v_vec * v;
    \\
    \\        // Direction and distance to sampled point
    \\        vec3 toLight = lightPoint - point;
    \\        float dist2 = dot(toLight, toLight);
    \\        float dist = sqrt(dist2);
    \\        vec3 lightDir = toLight / dist;
    \\
    \\        // Check if light is in front of surface
    \\        float cosTheta = dot(normal, lightDir);
    \\        if (cosTheta <= 0.0) continue;
    \\
    \\        // Check if we're on the emitting side of the light
    \\        float cosLight = -dot(alight.normal, lightDir);
    \\        if (cosLight <= 0.0) continue;
    \\
    \\        // Shadow ray
    \\        HitRecord shadowRec;
    \\        if (hit_world_bvh(point + normal * 0.002, lightDir, 0.001, dist - 0.01, shadowRec)) {
    \\            continue;  // Occluded
    \\        }
    \\
    \\        // Area light contribution with proper geometric term
    \\        // PDF = 1/area, geometric term = cos(theta) * cos(theta_light) / dist^2
    \\        float geometricTerm = cosTheta * cosLight / dist2;
    \\        vec3 lightContrib = albedo * alight.color * alight.intensity * alight.area;
    \\        direct += lightContrib * geometricTerm / PI;
    \\    }
    \\
    \\    return direct;
    \\}
    \\
    \\// ============ PROCEDURAL TEXTURES ============
    \\
    \\// Checker pattern
    \\vec3 tex_checker(vec2 uv, vec3 color1, vec3 color2, float scale) {
    \\    vec2 p = floor(uv * scale);
    \\    float c = mod(p.x + p.y, 2.0);
    \\    return mix(color1, color2, c);
    \\}
    \\
    \\// Brick pattern
    \\vec3 tex_brick(vec2 uv, vec3 brick_color, vec3 mortar_color, float scale) {
    \\    vec2 p = uv * scale;
    \\    float row = floor(p.y);
    \\    p.x += mod(row, 2.0) * 0.5;  // Offset every other row
    \\    vec2 brick = fract(p);
    \\    float mortar_width = 0.05;
    \\    float is_mortar = step(brick.x, mortar_width) + step(1.0 - mortar_width, brick.x) +
    \\                      step(brick.y, mortar_width) + step(1.0 - mortar_width, brick.y);
    \\    return mix(brick_color, mortar_color, clamp(is_mortar, 0.0, 1.0));
    \\}
    \\
    \\// Marble pattern using noise
    \\float noise_marble(vec2 p) {
    \\    return sin(p.x * 6.0 + 5.0 * (
    \\        sin(p.x * 4.0) * 0.5 + sin(p.y * 4.0) * 0.3 +
    \\        sin((p.x + p.y) * 3.0) * 0.2
    \\    )) * 0.5 + 0.5;
    \\}
    \\
    \\vec3 tex_marble(vec2 uv, vec3 color1, vec3 color2, float scale) {
    \\    float n = noise_marble(uv * scale);
    \\    return mix(color1, color2, n);
    \\}
    \\
    \\// Wood grain pattern
    \\vec3 tex_wood(vec2 uv, vec3 light_wood, vec3 dark_wood, float scale) {
    \\    vec2 p = uv * scale;
    \\    float r = length(p) * 10.0;
    \\    float ring = sin(r + sin(p.x * 2.0) * 2.0 + sin(p.y * 1.5) * 1.5) * 0.5 + 0.5;
    \\    return mix(light_wood, dark_wood, ring * ring);
    \\}
    \\
    \\// Sample procedural texture by ID
    \\vec3 sampleTexture(int tex_id, vec2 uv, vec3 base_color) {
    \\    if (tex_id == 0) return base_color;  // No texture
    \\    if (tex_id == 1) return tex_checker(uv, base_color, base_color * 0.2, 8.0);  // Checker
    \\    if (tex_id == 2) return tex_brick(uv, vec3(0.6, 0.2, 0.15), vec3(0.8, 0.8, 0.75), 4.0);  // Brick
    \\    if (tex_id == 3) return tex_marble(uv, vec3(0.95), vec3(0.3, 0.35, 0.4), 2.0);  // Marble
    \\    if (tex_id == 4) return tex_wood(uv, vec3(0.6, 0.4, 0.2), vec3(0.3, 0.15, 0.05), 1.0);  // Wood
    \\    return base_color;
    \\}
    \\
    \\// ============ NORMAL MAPPING ============
    \\
    \\// Simple hash for procedural noise
    \\float hash(vec2 p) {
    \\    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
    \\}
    \\
    \\// Smooth noise
    \\float noise(vec2 p) {
    \\    vec2 i = floor(p);
    \\    vec2 f = fract(p);
    \\    f = f * f * (3.0 - 2.0 * f);  // Smoothstep
    \\    float a = hash(i);
    \\    float b = hash(i + vec2(1.0, 0.0));
    \\    float c = hash(i + vec2(0.0, 1.0));
    \\    float d = hash(i + vec2(1.0, 1.0));
    \\    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
    \\}
    \\
    \\// FBM noise for more detail
    \\float fbm(vec2 p, int octaves) {
    \\    float value = 0.0;
    \\    float amplitude = 0.5;
    \\    for (int i = 0; i < octaves; i++) {
    \\        value += amplitude * noise(p);
    \\        p *= 2.0;
    \\        amplitude *= 0.5;
    \\    }
    \\    return value;
    \\}
    \\
    \\// Get height value for different texture types
    \\float getHeight(vec2 uv, int tex_id, float scale) {
    \\    if (tex_id == 1) {
    \\        // Checker - slight height difference at edges
    \\        vec2 p = uv * scale * 8.0;
    \\        vec2 f = fract(p);
    \\        float edge = min(min(f.x, 1.0-f.x), min(f.y, 1.0-f.y));
    \\        return smoothstep(0.0, 0.1, edge) * 0.1;
    \\    }
    \\    if (tex_id == 2) {
    \\        // Brick - mortar is lower, brick surface has noise
    \\        vec2 p = uv * 4.0;
    \\        float row = floor(p.y);
    \\        p.x += mod(row, 2.0) * 0.5;
    \\        vec2 brick = fract(p);
    \\        float mortar_width = 0.05;
    \\        float is_mortar = step(brick.x, mortar_width) + step(1.0 - mortar_width, brick.x) +
    \\                          step(brick.y, mortar_width) + step(1.0 - mortar_width, brick.y);
    \\        float brick_noise = fbm(uv * 20.0, 3) * 0.1;
    \\        return mix(0.3 + brick_noise, 0.0, clamp(is_mortar, 0.0, 1.0));
    \\    }
    \\    if (tex_id == 3) {
    \\        // Marble - veins are slightly recessed
    \\        return noise_marble(uv * 2.0) * 0.15;
    \\    }
    \\    if (tex_id == 4) {
    \\        // Wood - rings create subtle bumps
    \\        vec2 p = uv * 1.0;
    \\        float r = length(p) * 10.0;
    \\        float ring = sin(r + sin(p.x * 2.0) * 2.0 + sin(p.y * 1.5) * 1.5) * 0.5 + 0.5;
    \\        return ring * ring * 0.1;
    \\    }
    \\    return 0.0;
    \\}
    \\
    \\// Compute normal from height using finite differences
    \\vec3 heightToNormal(vec2 uv, float scale, int tex_id) {
    \\    float eps = 0.001;
    \\    float h0 = getHeight(uv, tex_id, scale);
    \\    float hx = getHeight(uv + vec2(eps, 0.0), tex_id, scale);
    \\    float hy = getHeight(uv + vec2(0.0, eps), tex_id, scale);
    \\    vec3 n = normalize(vec3(h0 - hx, h0 - hy, eps * 2.0));
    \\    return n;
    \\}
    \\
    \\// Build TBN matrix for compute shader (no dFdx/dFdy available)
    \\mat3 buildTBN_compute(vec3 N) {
    \\    // Create arbitrary tangent perpendicular to normal
    \\    vec3 up = abs(N.y) < 0.999 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
    \\    vec3 T = normalize(cross(up, N));
    \\    vec3 B = cross(N, T);
    \\    return mat3(T, B, N);
    \\}
    \\
    \\// Apply normal map perturbation
    \\vec3 applyNormalMap(vec3 N, vec2 uv, int tex_id, float strength) {
    \\    if (tex_id == 0) return N;  // No normal mapping
    \\
    \\    // Get tangent space normal from height map
    \\    vec3 tangentNormal = heightToNormal(uv, 1.0, tex_id);
    \\
    \\    // Scale the perturbation
    \\    tangentNormal.xy *= strength;
    \\    tangentNormal = normalize(tangentNormal);
    \\
    \\    // Transform from tangent space to world space
    \\    mat3 TBN = buildTBN_compute(N);
    \\    return normalize(TBN * tangentNormal);
    \\}
    \\
    \\// ============ DISPLACEMENT / PARALLAX MAPPING ============
    \\
    \\// Parallax Occlusion Mapping - creates illusion of displaced geometry
    \\vec2 parallaxMapping(vec2 uv, vec3 viewDir, int tex_id, float heightScale) {
    \\    if (tex_id == 0 || heightScale <= 0.0) return uv;
    \\
    \\    // Number of layers for ray marching
    \\    const float minLayers = 8.0;
    \\    const float maxLayers = 32.0;
    \\    float numLayers = mix(maxLayers, minLayers, abs(dot(vec3(0,0,1), viewDir)));
    \\
    \\    float layerDepth = 1.0 / numLayers;
    \\    float currentLayerDepth = 0.0;
    \\
    \\    // Direction to shift UV coords per layer
    \\    vec2 P = viewDir.xy * heightScale;
    \\    vec2 deltaUV = P / numLayers;
    \\
    \\    vec2 currentUV = uv;
    \\    float currentHeight = getHeight(currentUV, tex_id, 1.0);
    \\
    \\    // Ray march through height layers
    \\    for (int i = 0; i < 32 && currentLayerDepth < currentHeight; i++) {
    \\        currentUV -= deltaUV;
    \\        currentHeight = getHeight(currentUV, tex_id, 1.0);
    \\        currentLayerDepth += layerDepth;
    \\    }
    \\
    \\    // Interpolation for smoother result
    \\    vec2 prevUV = currentUV + deltaUV;
    \\    float afterDepth = currentHeight - currentLayerDepth;
    \\    float beforeDepth = getHeight(prevUV, tex_id, 1.0) - currentLayerDepth + layerDepth;
    \\    float weight = afterDepth / (afterDepth - beforeDepth);
    \\
    \\    return mix(currentUV, prevUV, weight);
    \\}
    \\
    \\// Apply displacement to hit record - modifies UV and recalculates position
    \\void applyDisplacement(inout HitRecord rec, vec3 viewDir, float strength) {
    \\    if (rec.texture_id == 0 || strength <= 0.0) return;
    \\
    \\    // Transform view direction to tangent space (simplified)
    \\    mat3 TBN = buildTBN_compute(rec.normal);
    \\    vec3 tangentViewDir = transpose(TBN) * viewDir;
    \\
    \\    // Apply parallax mapping
    \\    vec2 newUV = parallaxMapping(rec.uv, tangentViewDir, rec.texture_id, strength * 0.1);
    \\    rec.uv = newUV;
    \\
    \\    // Optionally offset the hit point along normal based on height
    \\    float height = getHeight(newUV, rec.texture_id, 1.0);
    \\    rec.point -= rec.normal * height * strength * 0.05;
    \\}
    \\
    \\// ============ TEMPORAL/SPATIAL DENOISING ============
    \\
    \\// Edge-aware spatial denoising using bilateral filtering
    \\vec3 spatialDenoise(ivec2 pixel, vec3 centerColor, float sampleCount) {
    \\    if (u_denoise <= 0.0) return centerColor;
    \\
    \\    // Adaptive kernel - larger at low sample counts
    \\    float adaptiveStrength = u_denoise * (1.0 / (1.0 + sampleCount * 0.1));
    \\    if (adaptiveStrength < 0.01) return centerColor;
    \\
    \\    float centerLum = dot(centerColor, vec3(0.299, 0.587, 0.114));
    \\
    \\    // 3x3 edge-aware filter
    \\    vec3 sum = centerColor;
    \\    float weightSum = 1.0;
    \\
    \\    // Spatial sigma (pixels)
    \\    float sigmaSpatial = 1.5;
    \\    // Range sigma (luminance difference)
    \\    float sigmaRange = 0.1 + (1.0 - adaptiveStrength) * 0.3;
    \\
    \\    for (int dy = -1; dy <= 1; dy++) {
    \\        for (int dx = -1; dx <= 1; dx++) {
    \\            if (dx == 0 && dy == 0) continue;
    \\
    \\            ivec2 samplePixel = pixel + ivec2(dx, dy);
    \\            samplePixel = clamp(samplePixel, ivec2(0), ivec2(u_width - 1, u_height - 1));
    \\
    \\            vec4 sampleAccum = imageLoad(accumImage, samplePixel);
    \\            vec3 sampleColor = sampleAccum.rgb / max(sampleAccum.a, 1.0);
    \\            float sampleLum = dot(sampleColor, vec3(0.299, 0.587, 0.114));
    \\
    \\            // Spatial weight (Gaussian)
    \\            float spatialDist = length(vec2(dx, dy));
    \\            float spatialWeight = exp(-spatialDist * spatialDist / (2.0 * sigmaSpatial * sigmaSpatial));
    \\
    \\            // Range weight (edge-preserving)
    \\            float lumDiff = abs(centerLum - sampleLum);
    \\            float rangeWeight = exp(-lumDiff * lumDiff / (2.0 * sigmaRange * sigmaRange));
    \\
    \\            float weight = spatialWeight * rangeWeight * adaptiveStrength;
    \\            sum += sampleColor * weight;
    \\            weightSum += weight;
    \\        }
    \\    }
    \\
    \\    return sum / weightSum;
    \\}
    \\
    \\// Variance-based adaptive filtering for very noisy regions
    \\vec3 varianceGuidedDenoise(ivec2 pixel, vec3 baseResult, float sampleCount) {
    \\    if (u_denoise <= 0.0 || sampleCount > 64.0) return baseResult;
    \\
    \\    // Calculate local variance in 3x3 neighborhood
    \\    vec3 mean = vec3(0.0);
    \\    vec3 meanSq = vec3(0.0);
    \\    float count = 0.0;
    \\
    \\    for (int dy = -1; dy <= 1; dy++) {
    \\        for (int dx = -1; dx <= 1; dx++) {
    \\            ivec2 samplePixel = pixel + ivec2(dx, dy);
    \\            samplePixel = clamp(samplePixel, ivec2(0), ivec2(u_width - 1, u_height - 1));
    \\
    \\            vec4 sampleAccum = imageLoad(accumImage, samplePixel);
    \\            vec3 c = sampleAccum.rgb / max(sampleAccum.a, 1.0);
    \\            mean += c;
    \\            meanSq += c * c;
    \\            count += 1.0;
    \\        }
    \\    }
    \\
    \\    mean /= count;
    \\    vec3 variance = meanSq / count - mean * mean;
    \\    float totalVariance = dot(variance, vec3(1.0));
    \\
    \\    // Higher variance = more denoising needed
    \\    float varianceStrength = clamp(totalVariance * 10.0, 0.0, 1.0) * u_denoise;
    \\
    \\    // Blend towards local mean in high-variance areas
    \\    return mix(baseResult, mean, varianceStrength * 0.3);
    \\}
    \\
    \\// ============ VOLUMETRIC FOG & GOD RAYS ============
    \\
    \\// Henyey-Greenstein phase function for anisotropic scattering
    \\float phaseHG(float cosTheta, float g) {
    \\    float g2 = g * g;
    \\    float denom = 1.0 + g2 - 2.0 * g * cosTheta;
    \\    return (1.0 - g2) / (4.0 * PI * pow(denom, 1.5));
    \\}
    \\
    \\// Sample volumetric fog along a ray segment
    \\vec3 sampleVolume(vec3 ro, vec3 rd, float t_max, vec3 pathColor) {
    \\    if (u_fog_density <= 0.0) return pathColor;
    \\
    \\    // Ray march parameters
    \\    const int VOL_STEPS = 16;
    \\    float step_size = min(t_max, 50.0) / float(VOL_STEPS);
    \\
    \\    vec3 accumulated_light = vec3(0.0);
    \\    float transmittance = 1.0;
    \\
    \\    // Sun direction for god rays
    \\    vec3 sun_dir = normalize(vec3(0.5, 0.35, -0.7));
    \\    vec3 sun_color = vec3(1.0, 0.9, 0.7) * 5.0;
    \\
    \\    for (int i = 0; i < VOL_STEPS; i++) {
    \\        float t = (float(i) + rand()) * step_size;
    \\        if (t > t_max) break;
    \\
    \\        vec3 pos = ro + rd * t;
    \\
    \\        // Height-based density falloff (thicker near ground)
    \\        float height_factor = exp(-max(pos.y, 0.0) * 0.15);
    \\        float local_density = u_fog_density * height_factor;
    \\
    \\        // Extinction
    \\        float extinction = local_density * step_size;
    \\        transmittance *= exp(-extinction);
    \\
    \\        if (transmittance < 0.01) break;
    \\
    \\        // In-scattering: check visibility to sun for god rays
    \\        HitRecord shadow_rec;
    \\        bool in_shadow = hit_world_bvh(pos, sun_dir, 0.01, 100.0, shadow_rec);
    \\
    \\        if (!in_shadow) {
    \\            // Phase function for forward scattering (g > 0 = forward)
    \\            float cosTheta = dot(rd, sun_dir);
    \\            float phase = phaseHG(cosTheta, 0.6);
    \\
    \\            // Add in-scattered light
    \\            vec3 inscatter = sun_color * phase * local_density * transmittance;
    \\            accumulated_light += inscatter * step_size;
    \\        }
    \\
    \\        // Ambient in-scattering (sky contribution)
    \\        vec3 ambient = getSky(vec3(0, 1, 0)) * 0.1;
    \\        accumulated_light += ambient * u_fog_color * local_density * transmittance * step_size;
    \\    }
    \\
    \\    // Combine: attenuated path color + accumulated fog light
    \\    return pathColor * transmittance + accumulated_light * u_fog_color;
    \\}
    \\
    \\vec3 trace(vec3 ro, vec3 rd) {
    \\    vec3 color = vec3(1.0);
    \\    vec3 light = vec3(0.0);
    \\
    \\    for (int depth = 0; depth < MAX_DEPTH; depth++) {
    \\        HitRecord rec;
    \\        if (hit_world_bvh(ro, rd, 0.001, 1e30, rec)) {
    \\            // Get material properties - simplified
    \\            int mat_type = 0;
    \\            vec3 albedo = vec3(0.5);
    \\            float fuzz = 0.0;
    \\            float ior = 1.5;
    \\            float emissive = 0.0;
    \\
    \\            if (rec.is_csg) {
    \\                CSGObject csg = csg_objects[rec.sphere_idx];
    \\                mat_type = csg.mat_type;
    \\                albedo = csg.albedo;
    \\                fuzz = csg.fuzz;
    \\                ior = csg.ior;
    \\                emissive = csg.emissive;
    \\            } else if (rec.is_triangle) {
    \\                Triangle tri = triangles[rec.sphere_idx];
    \\                mat_type = tri.mat_type;
    \\                albedo = tri.albedo;
    \\                fuzz = 0.1;
    \\                emissive = tri.emissive;
    \\            } else {
    \\                Sphere s = spheres[rec.sphere_idx];
    \\                mat_type = s.mat_type;
    \\                albedo = s.albedo;
    \\                fuzz = s.fuzz;
    \\                ior = s.ior;
    \\                emissive = s.emissive;
    \\            }
    \\
    \\            // Emissive (lights)
    \\            if (mat_type == 3) {
    \\                light += color * albedo * emissive;
    \\                break;
    \\            }
    \\
    \\            // Russian roulette after a few bounces
    \\            if (depth > 2) {
    \\                float p = max(color.x, max(color.y, color.z));
    \\                if (rand() > p) break;
    \\                color /= p;
    \\            }
    \\
    \\            // Simplified materials
    \\            if (mat_type == 0) {
    \\                // Diffuse with simple direct sun lighting
    \\                vec3 sun_dir = normalize(vec3(0.5, 0.35, -0.7));
    \\                float sun_ndotl = max(dot(rec.normal, sun_dir), 0.0);
    \\                if (sun_ndotl > 0.0) {
    \\                    // Simple shadow check - just test if sun is blocked
    \\                    HitRecord shadow_rec;
    \\                    if (!hit_world_bvh(rec.point + rec.normal * 0.002, sun_dir, 0.001, 1000.0, shadow_rec)) {
    \\                        light += color * albedo * sun_ndotl * vec3(1.0, 0.98, 0.9) * 2.0;
    \\                    }
    \\                }
    \\                vec3 scatter = rec.normal + random_unit_vector();
    \\                if (length(scatter) < 0.0001) scatter = rec.normal;
    \\                rd = normalize(scatter);
    \\                ro = rec.point + rec.normal * 0.001;
    \\                color *= albedo;
    \\            } else if (mat_type == 1) {
    \\                // Metal - simple reflection
    \\                vec3 reflected = reflect(rd, rec.normal);
    \\                rd = normalize(reflected + fuzz * random_unit_vector());
    \\                ro = rec.point + rec.normal * 0.001;
    \\                color *= albedo;
    \\                if (dot(rd, rec.normal) <= 0.0) break;
    \\            } else if (mat_type == 2) {
    \\                // Glass - simple refraction
    \\                float ratio = rec.front_face ? (1.0/ior) : ior;
    \\                float cos_theta = min(dot(-rd, rec.normal), 1.0);
    \\                float sin_theta = sqrt(1.0 - cos_theta*cos_theta);
    \\                bool cannot_refract = ratio * sin_theta > 1.0;
    \\                float r = reflectance(cos_theta, ior);
    \\                if (cannot_refract || rand() < r) {
    \\                    rd = reflect(rd, rec.normal);
    \\                    ro = rec.point + rec.normal * 0.001;
    \\                } else {
    \\                    rd = refract(rd, rec.normal, ratio);
    \\                    ro = rec.point - rec.normal * 0.001;
    \\                }
    \\                color *= albedo;
    \\            } else if (mat_type == 4) {
    \\                // SSS - treat as diffuse
    \\                vec3 scatter = rec.normal + random_unit_vector();
    \\                if (length(scatter) < 0.0001) scatter = rec.normal;
    \\                rd = normalize(scatter);
    \\                ro = rec.point + rec.normal * 0.001;
    \\                color *= albedo;
    \\            } else {
    \\                // Unknown - diffuse fallback
    \\                vec3 scatter = rec.normal + random_unit_vector();
    \\                rd = normalize(scatter);
    \\                ro = rec.point + rec.normal * 0.001;
    \\                color *= albedo;
    \\            }
    \\        } else {
    \\            // Sky
    \\            vec3 sky = getSky(rd);
    \\            light += color * sky;
    \\            break;
    \\        }
    \\    }
    \\    return light;
    \\}
    \\
    \\vec3 trace_FULL_DISABLED(vec3 ro, vec3 rd) {
    \\    vec3 color = vec3(1.0);
    \\    vec3 light = vec3(0.0);
    \\
    \\    for (int depth = 0; depth < MAX_DEPTH; depth++) {
    \\        HitRecord rec;
    \\        if (hit_world_bvh(ro, rd, 0.001, 1e30, rec)) {
    \\            // Get material properties from either triangle or sphere
    \\            int mat_type;
    \\            vec3 albedo;
    \\            float fuzz_or_roughness;
    \\            float ior;
    \\            float emissive;
    \\
    \\            if (rec.is_csg) {
    \\                CSGObject csg = csg_objects[rec.sphere_idx];
    \\                mat_type = csg.mat_type;
    \\                albedo = csg.albedo;
    \\                fuzz_or_roughness = csg.fuzz;
    \\                ior = csg.ior;
    \\                emissive = csg.emissive;
    \\            } else if (rec.is_triangle) {
    \\                Triangle tri = triangles[rec.sphere_idx];
    \\                mat_type = tri.mat_type;
    \\                albedo = sampleTexture(rec.texture_id, rec.uv, tri.albedo);
    \\                fuzz_or_roughness = 0.1;  // Default roughness for triangles
    \\                ior = 1.5;
    \\                emissive = tri.emissive;
    \\            } else {
    \\                Sphere s = spheres[rec.sphere_idx];
    \\                mat_type = s.mat_type;
    \\                albedo = s.albedo;
    \\                fuzz_or_roughness = s.fuzz;
    \\                ior = s.ior;
    \\                emissive = s.emissive;
    \\            }
    \\
    \\            // Apply displacement mapping (parallax) for textured surfaces
    \\            if (rec.texture_id > 0 && u_displacement > 0.0) {
    \\                applyDisplacement(rec, -rd, u_displacement);
    \\            }
    \\
    \\            // Apply normal mapping for textured surfaces
    \\            if (rec.texture_id > 0 && u_normal_strength > 0.0) {
    \\                rec.normal = applyNormalMap(rec.normal, rec.uv, rec.texture_id, u_normal_strength);
    \\            }
    \\
    \\            // Emissive materials (lights)
    \\            if (mat_type == 3) {
    \\                light += color * albedo * emissive;
    \\                break;
    \\            }
    \\
    \\            // Russian roulette for efficiency after first few bounces
    \\            if (depth > 3) {
    \\                float p = max(color.x, max(color.y, color.z));
    \\                if (rand() > p) break;
    \\                color /= p;
    \\            }
    \\
    \\            // Lambertian diffuse with NEE
    \\            if (mat_type == 0) {
    \\                // Direct light sampling (NEE) for faster convergence
    \\                if (u_nee > 0.5) {
    \\                    light += color * sampleLights(rec.point, rec.normal, albedo);
    \\                }
    \\
    \\                vec3 scatter_dir = rec.normal + random_unit_vector();
    \\                if (length(scatter_dir) < 0.0001) scatter_dir = rec.normal;
    \\                rd = normalize(scatter_dir);
    \\                ro = rec.point + rec.normal * 0.001;
    \\
    \\                // Apply iridescence (thin-film interference)
    \\                vec3 finalAlbedo = albedo;
    \\                if (u_iridescence > 0.0) {
    \\                    float cosTheta = max(dot(-normalize(rd), rec.normal), 0.0);
    \\                    float thickness = fract(dot(rec.point, vec3(1.7, 2.3, 3.1))); // Vary thickness
    \\                    vec3 irid = thinFilmIridescence(cosTheta, thickness);
    \\                    finalAlbedo = mix(albedo, albedo * irid * 2.0, u_iridescence);
    \\                }
    \\
    \\                // Add glitter sparkle
    \\                if (u_glitter > 0.0) {
    \\                    float sparkle = glitterSparkle(rec.point, -rd, rec.normal, 100.0);
    \\                    light += color * sparkle * u_glitter * 5.0;
    \\                }
    \\
    \\                color *= finalAlbedo;
    \\            }
    \\            // Metal with GGX microfacet BRDF (with anisotropic option)
    \\            else if (mat_type == 1) {
    \\                vec3 V = -rd;
    \\                vec3 N = rec.normal;
    \\                float roughness = max(fuzz_or_roughness * u_roughness_mult, 0.04);
    \\
    \\                // Build tangent frame for anisotropic
    \\                vec3 up = abs(N.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
    \\                vec3 T = normalize(cross(up, N));
    \\                vec3 B = cross(N, T);
    \\
    \\                // Anisotropic roughness (brushed metal effect)
    \\                float ax = roughness;
    \\                float ay = roughness;
    \\                if (u_anisotropy > 0.0) {
    \\                    float aniso = u_anisotropy * 0.9;
    \\                    ax = max(roughness * (1.0 + aniso), 0.01);
    \\                    ay = max(roughness * (1.0 - aniso), 0.01);
    \\                }
    \\
    \\                // Anisotropic GGX importance sampling
    \\                vec2 Xi = vec2(rand(), rand());
    \\                float phi = 2.0 * PI * Xi.x;
    \\                float cosTheta = sqrt((1.0 - Xi.y) / (1.0 + (ax * ax * cos(phi) * cos(phi) + ay * ay * sin(phi) * sin(phi) - 1.0) * Xi.y));
    \\                float sinTheta = sqrt(max(0.0, 1.0 - cosTheta * cosTheta));
    \\
    \\                vec3 H_local = vec3(cos(phi) * sinTheta, sin(phi) * sinTheta, cosTheta);
    \\                vec3 H = normalize(T * H_local.x + B * H_local.y + N * H_local.z);
    \\                vec3 L = reflect(-V, H);
    \\
    \\                float NdotL = dot(N, L);
    \\                if (NdotL <= 0.0) break;
    \\
    \\                float NdotV = max(dot(N, V), 0.0);
    \\                float NdotH = max(dot(N, H), 0.0);
    \\                float VdotH = max(dot(V, H), 0.0);
    \\
    \\                // Cook-Torrance BRDF with anisotropic NDF
    \\                vec3 F0 = albedo;  // Metal uses albedo as F0
    \\                vec3 F = FresnelSchlick(VdotH, F0);
    \\                float G = GeometrySmith(N, V, L, roughness);
    \\                float D = (u_anisotropy > 0.0) ? AnisotropicGGX(N, H, T, B, ax, ay) : 1.0;
    \\
    \\                // Importance sampling weight
    \\                vec3 weight = F * G * VdotH / max(NdotH * NdotV, 0.001);
    \\
    \\                // Add iridescence to metal (like titanium, anodized aluminum)
    \\                if (u_iridescence > 0.0) {
    \\                    vec3 irid = thinFilmIridescence(VdotH, fract(dot(rec.point, vec3(3.1, 1.7, 2.3))));
    \\                    weight *= mix(vec3(1.0), irid, u_iridescence * 0.5);
    \\                }
    \\
    \\                rd = L;
    \\                ro = rec.point + rec.normal * 0.001;
    \\                color *= weight;
    \\            }
    \\            // Dielectric (glass) with dispersion
    \\            else if (mat_type == 2) {
    \\                vec3 unit_dir = normalize(rd);
    \\                float cos_theta = min(dot(-unit_dir, rec.normal), 1.0);
    \\                float sin_theta = sqrt(1.0 - cos_theta * cos_theta);
    \\
    \\                // Dispersion: different IOR for each wavelength (Cauchy's equation approximation)
    \\                // Red has lower IOR, blue has higher IOR
    \\                float dispersion_amount = u_dispersion * 0.05;
    \\                vec3 ior_rgb = vec3(
    \\                    ior - dispersion_amount,  // Red (longer wavelength)
    \\                    ior,                       // Green (reference)
    \\                    ior + dispersion_amount   // Blue (shorter wavelength)
    \\                );
    \\
    \\                // Pick wavelength based on random selection for spectral rendering
    \\                float wavelength_choice = rand();
    \\                float selected_ior;
    \\                vec3 wavelength_color;
    \\                if (u_dispersion > 0.01 && !rec.front_face) {
    \\                    // Only apply dispersion on exit from glass (internal dispersion)
    \\                    if (wavelength_choice < 0.333) {
    \\                        selected_ior = ior_rgb.r;
    \\                        wavelength_color = vec3(1.5, 0.3, 0.3); // Emphasize red
    \\                    } else if (wavelength_choice < 0.666) {
    \\                        selected_ior = ior_rgb.g;
    \\                        wavelength_color = vec3(0.3, 1.5, 0.3); // Emphasize green
    \\                    } else {
    \\                        selected_ior = ior_rgb.b;
    \\                        wavelength_color = vec3(0.3, 0.3, 1.5); // Emphasize blue
    \\                    }
    \\                    color *= wavelength_color;
    \\                } else {
    \\                    selected_ior = ior;
    \\                }
    \\
    \\                float ri = rec.front_face ? (1.0 / selected_ior) : selected_ior;
    \\                bool cannot_refract = ri * sin_theta > 1.0;
    \\
    \\                if (cannot_refract || reflectance(cos_theta, ri) > rand()) {
    \\                    rd = reflect(unit_dir, rec.normal);
    \\                    ro = rec.point + rec.normal * 0.001;
    \\                } else {
    \\                    rd = refract(unit_dir, rec.normal, ri);
    \\                    ro = rec.point - rec.normal * 0.001;
    \\                }
    \\            }
    \\            // Subsurface scattering (SSS) - for skin, wax, marble, jade
    \\            else if (mat_type == 4) {
    \\                // SSS uses fuzz as scatter distance (mean free path)
    \\                float scatter_dist = max(fuzz_or_roughness, 0.05);
    \\                vec3 subsurface_color = albedo;
    \\
    \\                // Fresnel determines reflection vs transmission
    \\                float cos_theta = max(dot(-rd, rec.normal), 0.0);
    \\                float fresnel = 0.04 + 0.96 * pow(1.0 - cos_theta, 5.0);
    \\
    \\                if (rand() < fresnel) {
    \\                    // Surface reflection - diffuse-like
    \\                    vec3 scatter_dir = rec.normal + random_unit_vector();
    \\                    if (length(scatter_dir) < 0.0001) scatter_dir = rec.normal;
    \\                    rd = normalize(scatter_dir);
    \\                    ro = rec.point + rec.normal * 0.001;
    \\                    color *= albedo * 0.5;
    \\                } else {
    \\                    // Subsurface scattering - light enters and scatters inside
    \\                    vec3 scatter_pos = rec.point;
    \\                    vec3 scatter_dir = normalize(-rec.normal + random_unit_vector() * 0.8);
    \\                    float total_dist = 0.0;
    \\
    \\                    // Random walk inside the material
    \\                    const int SSS_STEPS = 4;
    \\                    for (int i = 0; i < SSS_STEPS; i++) {
    \\                        float step_dist = -log(max(rand(), 0.0001)) * scatter_dist;
    \\                        scatter_pos += scatter_dir * step_dist;
    \\                        total_dist += step_dist;
    \\                        scatter_dir = normalize(scatter_dir + random_unit_vector());
    \\                    }
    \\
    \\                    // Exit in a random direction from approximate exit point
    \\                    vec3 exit_offset = scatter_pos - rec.point;
    \\                    float exit_dist = length(exit_offset);
    \\
    \\                    // Approximate exit point on surface (project back)
    \\                    vec3 exit_point = rec.point + normalize(exit_offset) * min(exit_dist, scatter_dist * 2.0);
    \\                    exit_point += rec.normal * 0.001;
    \\
    \\                    // Attenuation based on distance traveled
    \\                    vec3 sigma_a = vec3(1.0) / (subsurface_color + 0.001);
    \\                    vec3 attenuation = exp(-sigma_a * total_dist * 0.5);
    \\
    \\                    // Exit direction - diffuse from surface
    \\                    rd = normalize(rec.normal + random_unit_vector());
    \\                    ro = exit_point;
    \\                    color *= attenuation * albedo;
    \\                }
    \\            }
    \\        } else {
    \\            // Ray missed - sample sky with volumetric fog
    \\            vec3 sky = getSky(rd);
    \\            if (u_fog_density > 0.0) {
    \\                sky = sampleVolume(ro, rd, 100.0, sky);
    \\            }
    \\            light += color * sky;
    \\            break;
    \\        }
    \\    }
    \\    return light;
    \\}
    \\
    \\void main() {
    \\    ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
    \\    if (pixel.x >= u_width || pixel.y >= u_height) return;
    \\
    \\    // Unique random seed per pixel, frame, AND sample
    \\    uint seed_base = uint(pixel.x) + uint(pixel.y) * uint(u_width);
    \\    state = pcg_hash(seed_base + (u_frame * 4u + u_sample) * uint(u_width) * uint(u_height));
    \\
    \\    float u = (float(pixel.x) + rand()) / float(u_width);
    \\    float v = (float(pixel.y) + rand()) / float(u_height);
    \\
    \\    vec2 uv = vec2(u, 1.0 - v) * 2.0 - 1.0;
    \\    uv.x *= u_aspect;
    \\
    \\    // Ray with optional depth of field
    \\    vec3 rd = normalize(u_camera_forward * u_fov_scale + u_camera_right * uv.x + u_camera_up * uv.y);
    \\    vec3 ro = u_camera_pos;
    \\
    \\    // Apply depth of field if aperture > 0
    \\    if (u_aperture > 0.0) {
    \\        vec3 focus_point = ro + rd * u_focus_dist;
    \\        vec3 disk = sample_bokeh_aperture();
    \\        vec3 offset = (u_camera_right * disk.x + u_camera_up * disk.y) * u_aperture;
    \\        ro = u_camera_pos + offset;
    \\        rd = normalize(focus_point - ro);
    \\    }
    \\
    \\    // Reset intersection counter for this ray
    \\    g_intersection_count = 0;
    \\
    \\    // Debug visualization modes - handle BEFORE trace() to avoid expensive path tracing
    \\    if (u_debug_mode == 1) {
    \\        // BVH heatmap - only need to count intersections, not full path trace
    \\        HitRecord rec;
    \\        hit_world_bvh(ro, rd, 0.001, 1e30, rec);
    \\        vec3 color = intersectionHeatmap(g_intersection_count);
    \\        imageStore(outputImage, pixel, vec4(color, 1.0));
    \\        imageStore(accumImage, pixel, vec4(color, 1.0));
    \\        return;
    \\    } else if (u_debug_mode == 2) {
    \\        // Normal visualization - single ray, no bounces
    \\        HitRecord rec;
    \\        vec3 color;
    \\        if (hit_world_bvh(ro, rd, 0.001, 1e30, rec)) {
    \\            color = rec.normal * 0.5 + 0.5; // Map -1..1 to 0..1
    \\        } else {
    \\            color = vec3(0.0);
    \\        }
    \\        imageStore(outputImage, pixel, vec4(color, 1.0));
    \\        imageStore(accumImage, pixel, vec4(color, 1.0));
    \\        return;
    \\    } else if (u_debug_mode == 3) {
    \\        // Depth visualization - single ray, no bounces
    \\        HitRecord rec;
    \\        vec3 color;
    \\        if (hit_world_bvh(ro, rd, 0.001, 1e30, rec)) {
    \\            float depth = 1.0 - clamp(rec.t / 50.0, 0.0, 1.0); // White = close, black = far
    \\            color = vec3(depth);
    \\        } else {
    \\            color = vec3(0.0);
    \\        }
    \\        imageStore(outputImage, pixel, vec4(color, 1.0));
    \\        imageStore(accumImage, pixel, vec4(color, 1.0));
    \\        return;
    \\    }
    \\
    \\    // Path trace the scene
    \\    vec3 color = trace(ro, rd);
    \\
    \\    // Accumulation logic - reset ONLY on frame 1, sample 0
    \\    vec4 accum;
    \\    if (u_frame == 1u && u_sample == 0u) {
    \\        // First sample of first frame after camera move - start fresh
    \\        accum = vec4(color, 1.0);
    \\    } else {
    \\        accum = imageLoad(accumImage, pixel);
    \\        accum.rgb += color;
    \\        accum.a += 1.0;
    \\    }
    \\    imageStore(accumImage, pixel, accum);
    \\
    \\    // Post-processing pipeline
    \\    vec3 result = accum.rgb / accum.a;
    \\
    \\    // Temporal/spatial denoising - adaptive based on sample count
    \\    if (u_denoise > 0.0 && accum.a < 32.0) {  // Skip after enough samples
    \\        result = spatialDenoise(pixel, result, accum.a);
    \\        result = varianceGuidedDenoise(pixel, result, accum.a);
    \\    }
    \\
    \\    // Chromatic aberration - only run if enabled (expensive!)
    \\    if (u_chromatic > 0.0001) {
    \\        vec2 center = vec2(u_width, u_height) * 0.5;
    \\        vec2 pixelVec = vec2(pixel) - center;
    \\        float dist = length(pixelVec) / length(center);
    \\        float chromaStrength = u_chromatic * dist * dist;
    \\
    \\        vec2 redOffset = pixelVec * (1.0 + chromaStrength);
    \\        vec2 blueOffset = pixelVec * (1.0 - chromaStrength);
    \\
    \\        ivec2 redPixel = clamp(ivec2(center + redOffset), ivec2(0), ivec2(u_width - 1, u_height - 1));
    \\        ivec2 bluePixel = clamp(ivec2(center + blueOffset), ivec2(0), ivec2(u_width - 1, u_height - 1));
    \\
    \\        vec4 redAccum = imageLoad(accumImage, redPixel);
    \\        vec4 blueAccum = imageLoad(accumImage, bluePixel);
    \\
    \\        result.r = redAccum.r / max(redAccum.a, 1.0);
    \\        result.b = blueAccum.b / max(blueAccum.a, 1.0);
    \\    }
    \\
    \\    // Motion blur based on camera movement - only if enabled
    \\    if (u_motion_blur > 0.0001) {
    \\        vec3 cameraDelta = u_camera_pos - u_prev_camera_pos;
    \\        vec3 forwardDelta = u_camera_forward - u_prev_camera_forward;
    \\        float motionMag = length(cameraDelta) + length(forwardDelta) * 2.0;
    \\
    \\        if (motionMag > 0.001) {
    \\        // Calculate screen-space velocity from camera motion
    \\        vec2 screenUV = (vec2(pixel) / vec2(u_width, u_height)) * 2.0 - 1.0;
    \\        vec3 viewDir = normalize(u_camera_forward + u_camera_right * screenUV.x * u_aspect + u_camera_up * screenUV.y);
    \\        vec3 prevViewDir = normalize(u_prev_camera_forward + u_camera_right * screenUV.x * u_aspect + u_camera_up * screenUV.y);
    \\
    \\        // Project to screen space velocity
    \\        vec2 velocity = (viewDir.xy - prevViewDir.xy) * 50.0 + cameraDelta.xy * 10.0;
    \\        velocity = clamp(velocity, vec2(-20.0), vec2(20.0));
    \\
    \\        // Sample along motion vector
    \\        float blurStrength = min(motionMag * u_motion_blur, 1.0);
    \\        if (length(velocity) > 0.5) {
    \\            vec3 motionBlurred = result;
    \\            float totalWeight = 1.0;
    \\            const int BLUR_SAMPLES = 5;
    \\            for (int i = 1; i <= BLUR_SAMPLES; i++) {
    \\                float t = float(i) / float(BLUR_SAMPLES);
    \\                ivec2 samplePos = pixel + ivec2(velocity * t * blurStrength);
    \\                samplePos = clamp(samplePos, ivec2(0), ivec2(u_width - 1, u_height - 1));
    \\                vec4 sampleAccum = imageLoad(accumImage, samplePos);
    \\                float weight = 1.0 - t * 0.5;
    \\                motionBlurred += (sampleAccum.rgb / max(sampleAccum.a, 1.0)) * weight;
    \\                totalWeight += weight;
    \\            }
    \\            result = motionBlurred / totalWeight;
    \\        }
    \\        }
    \\    }
    \\
    \\    // Subtle bloom approximation for bright areas
    \\    float luminance = dot(result, vec3(0.299, 0.587, 0.114));
    \\    float bloom = max(0.0, luminance - 1.0) * u_bloom;
    \\    result += bloom * vec3(1.0, 0.9, 0.8);
    \\
    \\    // Lens flare effect - anamorphic streaks and ghosts
    \\    if (u_lens_flare > 0.0) {
    \\        vec2 uv = vec2(pixel) / vec2(u_width, u_height);
    \\        vec2 center = vec2(0.5);
    \\        vec3 flare = vec3(0.0);
    \\
    \\        // Sample multiple points looking for bright areas
    \\        const int FLARE_SAMPLES = 8;
    \\        for (int i = 0; i < FLARE_SAMPLES; i++) {
    \\            float angle = float(i) * 3.14159265 * 2.0 / float(FLARE_SAMPLES);
    \\            for (float dist = 0.1; dist < 0.5; dist += 0.1) {
    \\                vec2 sampleUV = center + vec2(cos(angle), sin(angle)) * dist;
    \\                ivec2 samplePixel = ivec2(sampleUV * vec2(u_width, u_height));
    \\                samplePixel = clamp(samplePixel, ivec2(0), ivec2(u_width - 1, u_height - 1));
    \\                vec4 sampleVal = imageLoad(accumImage, samplePixel);
    \\                vec3 sampleColor = sampleVal.rgb / max(sampleVal.a, 1.0);
    \\                float sampleLum = dot(sampleColor, vec3(0.299, 0.587, 0.114));
    \\
    \\                // Only process very bright samples (lights/emissives)
    \\                if (sampleLum > 2.0) {
    \\                    // Ghost: mirror across center
    \\                    vec2 ghostUV = center + (center - sampleUV) * 0.7;
    \\                    vec2 ghostDir = normalize(uv - ghostUV);
    \\                    float ghostDist = length(uv - ghostUV);
    \\                    float ghostIntensity = max(0.0, 1.0 - ghostDist * 4.0) * (sampleLum - 2.0) * 0.1;
    \\                    vec3 ghostColor = sampleColor * vec3(0.8, 0.9, 1.0); // Slightly blue tint
    \\                    flare += ghostColor * ghostIntensity;
    \\
    \\                    // Anamorphic horizontal streak
    \\                    vec2 lightScreenPos = sampleUV;
    \\                    float streakDist = abs(uv.y - lightScreenPos.y);
    \\                    float streakFalloff = exp(-streakDist * 20.0);
    \\                    float streakIntensity = streakFalloff * (sampleLum - 2.0) * 0.05;
    \\                    vec3 streakColor = sampleColor * vec3(1.0, 0.8, 0.6); // Warm streak
    \\                    flare += streakColor * streakIntensity;
    \\
    \\                    // Starburst pattern around light
    \\                    vec2 toLight = uv - lightScreenPos;
    \\                    float lightAngle = atan(toLight.y, toLight.x);
    \\                    float starPattern = abs(sin(lightAngle * 6.0)); // 6-pointed star
    \\                    float starDist = length(toLight);
    \\                    float starIntensity = starPattern * exp(-starDist * 8.0) * (sampleLum - 2.0) * 0.03;
    \\                    flare += sampleColor * starIntensity;
    \\                }
    \\            }
    \\        }
    \\        result += flare * u_lens_flare;
    \\    }
    \\
    \\    // Exposure adjustment
    \\    result *= u_exposure;
    \\
    \\    // ACES filmic tone mapping (cinematic look)
    \\    result = (result * (2.51 * result + 0.03)) / (result * (2.43 * result + 0.59) + 0.14);
    \\
    \\    // Subtle contrast enhancement
    \\    result = pow(result, vec3(1.05));
    \\
    \\    // Gamma correction
    \\    result = pow(clamp(result, 0.0, 1.0), vec3(1.0 / 2.2));
    \\
    \\    // Vignette for cinematic look
    \\    vec2 uv_vignette = vec2(pixel) / vec2(u_width, u_height);
    \\    float vignette = 1.0 - u_vignette * length((uv_vignette - 0.5) * 1.2);
    \\    result *= vignette;
    \\
    \\    // Heat haze distortion
    \\    if (u_heat_haze > 0.0) {
    \\        vec2 uv = vec2(pixel) / vec2(u_width, u_height);
    \\        vec2 offset = heatHazeOffset(uv, float(u_frame) * 0.05, u_heat_haze);
    \\        ivec2 distortedPixel = ivec2((uv + offset) * vec2(u_width, u_height));
    \\        distortedPixel = clamp(distortedPixel, ivec2(0), ivec2(u_width - 1, u_height - 1));
    \\        vec4 distortedAccum = imageLoad(accumImage, distortedPixel);
    \\        vec3 distortedColor = distortedAccum.rgb / max(distortedAccum.a, 1.0);
    \\        // Apply same tonemapping to distorted sample
    \\        distortedColor *= u_exposure;
    \\        distortedColor = (distortedColor * (2.51 * distortedColor + 0.03)) / (distortedColor * (2.43 * distortedColor + 0.59) + 0.14);
    \\        distortedColor = pow(clamp(distortedColor, 0.0, 1.0), vec3(1.0 / 2.2));
    \\        result = mix(result, distortedColor, u_heat_haze * 0.5);
    \\    }
    \\
    \\    // Color temperature adjustment
    \\    if (abs(u_color_temp) > 0.01) {
    \\        result = adjustColorTemp(result, u_color_temp);
    \\    }
    \\
    \\    // Saturation adjustment
    \\    if (abs(u_saturation - 1.0) > 0.01) {
    \\        result = adjustSaturation(result, u_saturation);
    \\    }
    \\
    \\    // Tilt-shift miniature effect (blur top and bottom)
    \\    if (u_tilt_shift > 0.0) {
    \\        vec2 uv = vec2(pixel) / vec2(u_width, u_height);
    \\        float focusBand = 0.3; // Sharp band in the middle
    \\        float distFromCenter = abs(uv.y - 0.5) * 2.0;
    \\        float blurAmount = smoothstep(focusBand, 1.0, distFromCenter) * u_tilt_shift;
    \\
    \\        if (blurAmount > 0.01) {
    \\            vec3 blurred = result;
    \\            float blurRadius = blurAmount * 10.0;
    \\            for (int i = -3; i <= 3; i++) {
    \\                for (int j = -3; j <= 3; j++) {
    \\                    if (i == 0 && j == 0) continue;
    \\                    ivec2 samplePos = pixel + ivec2(int(float(i) * blurRadius), int(float(j) * blurRadius));
    \\                    samplePos = clamp(samplePos, ivec2(0), ivec2(u_width - 1, u_height - 1));
    \\                    vec4 sampleAccum = imageLoad(accumImage, samplePos);
    \\                    vec3 sampleColor = sampleAccum.rgb / max(sampleAccum.a, 1.0);
    \\                    sampleColor *= u_exposure;
    \\                    sampleColor = (sampleColor * (2.51 * sampleColor + 0.03)) / (sampleColor * (2.43 * sampleColor + 0.59) + 0.14);
    \\                    sampleColor = pow(clamp(sampleColor, 0.0, 1.0), vec3(1.0 / 2.2));
    \\                    blurred += sampleColor;
    \\                }
    \\            }
    \\            blurred /= 49.0;
    \\            result = mix(result, blurred, blurAmount);
    \\        }
    \\    }
    \\
    \\    // CRT scanlines effect
    \\    if (u_scanlines > 0.0) {
    \\        float scanline = sin(float(pixel.y) * 3.14159265) * 0.5 + 0.5;
    \\        scanline = pow(scanline, 1.5);
    \\        result *= mix(1.0, scanline, u_scanlines * 0.3);
    \\
    \\        // CRT curvature at edges
    \\        vec2 uv = vec2(pixel) / vec2(u_width, u_height);
    \\        vec2 curved = (uv - 0.5) * 2.0;
    \\        curved *= 1.0 + pow(length(curved), 2.0) * u_scanlines * 0.1;
    \\        curved = curved * 0.5 + 0.5;
    \\
    \\        // Slight RGB separation for CRT look
    \\        float rgbSep = u_scanlines * 0.002;
    \\        vec2 redOffset = vec2(rgbSep, 0.0);
    \\        vec2 blueOffset = vec2(-rgbSep, 0.0);
    \\        ivec2 redPixel = clamp(pixel + ivec2(redOffset * vec2(u_width, u_height)), ivec2(0), ivec2(u_width - 1, u_height - 1));
    \\        ivec2 bluePixel = clamp(pixel + ivec2(blueOffset * vec2(u_width, u_height)), ivec2(0), ivec2(u_width - 1, u_height - 1));
    \\        vec4 redAccum = imageLoad(accumImage, redPixel);
    \\        vec4 blueAccum = imageLoad(accumImage, bluePixel);
    \\        vec3 redSample = redAccum.rgb / max(redAccum.a, 1.0);
    \\        vec3 blueSample = blueAccum.rgb / max(blueAccum.a, 1.0);
    \\        result.r = mix(result.r, redSample.r * u_exposure, u_scanlines * 0.3);
    \\        result.b = mix(result.b, blueSample.b * u_exposure, u_scanlines * 0.3);
    \\
    \\        // Phosphor glow
    \\        result += result * u_scanlines * 0.1;
    \\    }
    \\
    \\    // ============ MEGA EFFECTS BATCH 2 POST-PROCESSING ============
    \\
    \\    // Fisheye lens distortion
    \\    if (u_fisheye > 0.0) {
    \\        vec2 uv = vec2(pixel) / vec2(u_width, u_height);
    \\        vec2 fishUV = fisheyeUV(uv, u_fisheye * 3.0);
    \\        ivec2 fishPixel = ivec2(fishUV * vec2(u_width, u_height));
    \\        fishPixel = clamp(fishPixel, ivec2(0), ivec2(u_width - 1, u_height - 1));
    \\        vec4 fishAccum = imageLoad(accumImage, fishPixel);
    \\        vec3 fishColor = fishAccum.rgb / max(fishAccum.a, 1.0);
    \\        fishColor *= u_exposure;
    \\        fishColor = (fishColor * (2.51 * fishColor + 0.03)) / (fishColor * (2.43 * fishColor + 0.59) + 0.14);
    \\        fishColor = pow(clamp(fishColor, 0.0, 1.0), vec3(1.0 / 2.2));
    \\        result = mix(result, fishColor, min(u_fisheye, 1.0));
    \\    }
    \\
    \\    // Kaleidoscope effect
    \\    if (u_kaleidoscope >= 3.0) {
    \\        vec2 uv = vec2(pixel) / vec2(u_width, u_height);
    \\        vec2 kaleUV = kaleidoscopeUV(uv, u_kaleidoscope);
    \\        ivec2 kalePixel = ivec2(kaleUV * vec2(u_width, u_height));
    \\        kalePixel = clamp(kalePixel, ivec2(0), ivec2(u_width - 1, u_height - 1));
    \\        vec4 kaleAccum = imageLoad(accumImage, kalePixel);
    \\        vec3 kaleColor = kaleAccum.rgb / max(kaleAccum.a, 1.0);
    \\        kaleColor *= u_exposure;
    \\        kaleColor = (kaleColor * (2.51 * kaleColor + 0.03)) / (kaleColor * (2.43 * kaleColor + 0.59) + 0.14);
    \\        kaleColor = pow(clamp(kaleColor, 0.0, 1.0), vec3(1.0 / 2.2));
    \\        result = kaleColor;
    \\    }
    \\
    \\    // Pixelation / Mosaic effect
    \\    if (u_pixelate > 0.0) {
    \\        float pixelSize = mix(1.0, 200.0, 1.0 - u_pixelate);
    \\        vec2 uv = vec2(pixel) / vec2(u_width, u_height);
    \\        vec2 pixUV = pixelateUV(uv, pixelSize);
    \\        ivec2 pixPixel = ivec2(pixUV * vec2(u_width, u_height));
    \\        pixPixel = clamp(pixPixel, ivec2(0), ivec2(u_width - 1, u_height - 1));
    \\        vec4 pixAccum = imageLoad(accumImage, pixPixel);
    \\        vec3 pixColor = pixAccum.rgb / max(pixAccum.a, 1.0);
    \\        pixColor *= u_exposure;
    \\        pixColor = (pixColor * (2.51 * pixColor + 0.03)) / (pixColor * (2.43 * pixColor + 0.59) + 0.14);
    \\        pixColor = pow(clamp(pixColor, 0.0, 1.0), vec3(1.0 / 2.2));
    \\        result = pixColor;
    \\    }
    \\
    \\    // Edge detection / Toon outline
    \\    if (u_edge_detect > 0.0) {
    \\        float edge = sobelEdge(pixel, u_width, u_height);
    \\        edge = smoothstep(0.0, 0.5, edge);
    \\        result = mix(result, vec3(0.0), edge * u_edge_detect);
    \\    }
    \\
    \\    // Halftone / Comic book effect
    \\    if (u_halftone > 0.0) {
    \\        vec2 uv = vec2(pixel) / vec2(u_width, u_height);
    \\        float dotSize = 40.0 + u_halftone * 60.0;
    \\        float dotC = halftonePattern(uv, dotSize, 0.26);
    \\        float dotM = halftonePattern(uv, dotSize, 0.79);
    \\        float dotY = halftonePattern(uv, dotSize, 0.0);
    \\        vec3 cmyk;
    \\        cmyk.r = step(dotC, result.r);
    \\        cmyk.g = step(dotM, result.g);
    \\        cmyk.b = step(dotY, result.b);
    \\        result = mix(result, cmyk, u_halftone);
    \\    }
    \\
    \\    // Night vision effect
    \\    if (u_night_vision > 0.0) {
    \\        result = nightVisionEffect(result, u_night_vision, pixel, u_frame);
    \\    }
    \\
    \\    // Thermal vision effect
    \\    if (u_thermal > 0.0) {
    \\        float heat = dot(result, vec3(0.299, 0.587, 0.114));
    \\        heat = pow(heat, 0.7);
    \\        vec3 thermalColor = thermalPalette(heat);
    \\        result = mix(result, thermalColor, u_thermal);
    \\    }
    \\
    \\    // Underwater effect with caustics
    \\    if (u_underwater > 0.0) {
    \\        vec2 uv = vec2(pixel) / vec2(u_width, u_height);
    \\        float time = float(u_frame) * 0.02;
    \\        vec3 underwaterTint = vec3(0.3, 0.5, 0.7);
    \\        result = mix(result, result * underwaterTint, u_underwater * 0.5);
    \\        float caustics = causticPattern(uv, time);
    \\        result += vec3(caustics * 0.3) * u_underwater;
    \\        result *= 1.0 - u_underwater * 0.3;
    \\    }
    \\
    \\    // Rain drops on lens
    \\    if (u_rain_drops > 0.0) {
    \\        vec2 uv = vec2(pixel) / vec2(u_width, u_height);
    \\        float time = float(u_frame) * 0.05;
    \\        vec2 rainOffset = rainDropOffset(uv, time, u_rain_drops);
    \\        ivec2 rainPixel = ivec2((uv + rainOffset) * vec2(u_width, u_height));
    \\        rainPixel = clamp(rainPixel, ivec2(0), ivec2(u_width - 1, u_height - 1));
    \\        vec4 rainAccum = imageLoad(accumImage, rainPixel);
    \\        vec3 rainColor = rainAccum.rgb / max(rainAccum.a, 1.0);
    \\        rainColor *= u_exposure;
    \\        rainColor = (rainColor * (2.51 * rainColor + 0.03)) / (rainColor * (2.43 * rainColor + 0.59) + 0.14);
    \\        rainColor = pow(clamp(rainColor, 0.0, 1.0), vec3(1.0 / 2.2));
    \\        result = mix(result, rainColor, u_rain_drops * 0.5);
    \\    }
    \\
    \\    // VHS / Old film effect
    \\    if (u_vhs_effect > 0.0) {
    \\        vec2 uv = vec2(pixel) / vec2(u_width, u_height);
    \\        result = vhsEffect(result, uv, u_frame, u_vhs_effect);
    \\        float vhsAberr = u_vhs_effect * 0.005;
    \\        ivec2 rOff = clamp(pixel + ivec2(int(vhsAberr * float(u_width)), 0), ivec2(0), ivec2(u_width-1, u_height-1));
    \\        ivec2 bOff = clamp(pixel - ivec2(int(vhsAberr * float(u_width)), 0), ivec2(0), ivec2(u_width-1, u_height-1));
    \\        vec4 rSamp = imageLoad(accumImage, rOff);
    \\        vec4 bSamp = imageLoad(accumImage, bOff);
    \\        result.r = mix(result.r, (rSamp.r / max(rSamp.a, 1.0)) * u_exposure, u_vhs_effect * 0.3);
    \\        result.b = mix(result.b, (bSamp.b / max(bSamp.a, 1.0)) * u_exposure, u_vhs_effect * 0.3);
    \\    }
    \\
    \\    // Anaglyph 3D (Red/Cyan)
    \\    if (u_anaglyph_3d > 0.0) {
    \\        float sep = u_anaglyph_3d * 0.01;
    \\        ivec2 leftPx = clamp(pixel - ivec2(int(sep * float(u_width)), 0), ivec2(0), ivec2(u_width-1, u_height-1));
    \\        ivec2 rightPx = clamp(pixel + ivec2(int(sep * float(u_width)), 0), ivec2(0), ivec2(u_width-1, u_height-1));
    \\        vec4 leftAcc = imageLoad(accumImage, leftPx);
    \\        vec4 rightAcc = imageLoad(accumImage, rightPx);
    \\        vec3 leftCol = leftAcc.rgb / max(leftAcc.a, 1.0);
    \\        vec3 rightCol = rightAcc.rgb / max(rightAcc.a, 1.0);
    \\        float leftLuma = dot(leftCol, vec3(0.299, 0.587, 0.114));
    \\        float rightLuma = dot(rightCol, vec3(0.299, 0.587, 0.114));
    \\        vec3 anaglyph = vec3(leftLuma, rightLuma * 0.7, rightLuma);
    \\        result = mix(result, anaglyph, u_anaglyph_3d);
    \\    }
    \\
    \\    // Posterization effect
    \\    if (u_posterize >= 2.0) {
    \\        result = posterize(result, u_posterize);
    \\    }
    \\
    \\    // Sepia / Vintage effect
    \\    if (u_sepia > 0.0) {
    \\        result = sepiaEffect(result, u_sepia);
    \\    }
    \\
    \\    // Frosted glass effect
    \\    if (u_frosted > 0.0) {
    \\        vec2 uv = vec2(pixel) / vec2(u_width, u_height);
    \\        vec3 frostedCol = vec3(0.0);
    \\        for (int i = 0; i < 8; i++) {
    \\            vec2 off = frostedOffset(uv + vec2(float(i) * 0.01), u_frosted, u_frame + uint(i));
    \\            ivec2 sp = clamp(pixel + ivec2(off * vec2(u_width, u_height)), ivec2(0), ivec2(u_width-1, u_height-1));
    \\            vec4 samp = imageLoad(accumImage, sp);
    \\            vec3 sc = samp.rgb / max(samp.a, 1.0);
    \\            sc *= u_exposure;
    \\            sc = (sc * (2.51 * sc + 0.03)) / (sc * (2.43 * sc + 0.59) + 0.14);
    \\            sc = pow(clamp(sc, 0.0, 1.0), vec3(1.0 / 2.2));
    \\            frostedCol += sc;
    \\        }
    \\        frostedCol /= 8.0;
    \\        result = mix(result, frostedCol, u_frosted);
    \\    }
    \\
    \\    // Radial / Zoom blur
    \\    if (u_radial_blur > 0.0) {
    \\        vec2 uv = vec2(pixel) / vec2(u_width, u_height);
    \\        vec3 blurCol = result;
    \\        for (int i = 1; i <= 8; i++) {
    \\            vec2 off = radialBlurOffset(uv, u_radial_blur, float(i));
    \\            ivec2 sp = clamp(ivec2((uv - off) * vec2(u_width, u_height)), ivec2(0), ivec2(u_width-1, u_height-1));
    \\            vec4 samp = imageLoad(accumImage, sp);
    \\            vec3 sc = samp.rgb / max(samp.a, 1.0);
    \\            sc *= u_exposure;
    \\            sc = (sc * (2.51 * sc + 0.03)) / (sc * (2.43 * sc + 0.59) + 0.14);
    \\            sc = pow(clamp(sc, 0.0, 1.0), vec3(1.0 / 2.2));
    \\            blurCol += sc;
    \\        }
    \\        blurCol /= 9.0;
    \\        result = mix(result, blurCol, u_radial_blur);
    \\    }
    \\
    \\    // Dithering effect
    \\    if (u_dither > 0.0) {
    \\        float dith = bayerDither(pixel);
    \\        float levels = mix(256.0, 4.0, u_dither);
    \\        result = floor(result * levels + dith) / levels;
    \\    }
    \\
    \\    // ASCII art mode
    \\    if (u_ascii_mode > 0.0) {
    \\        float luma = dot(result, vec3(0.299, 0.587, 0.114));
    \\        ivec2 blockSz = ivec2(int(4.0 + u_ascii_mode * 4.0));
    \\        ivec2 blockPos = pixel / blockSz * blockSz + blockSz / 2;
    \\        blockPos = clamp(blockPos, ivec2(0), ivec2(u_width-1, u_height-1));
    \\        vec4 blockAcc = imageLoad(accumImage, blockPos);
    \\        vec3 blockCol = blockAcc.rgb / max(blockAcc.a, 1.0);
    \\        float blockLuma = dot(blockCol, vec3(0.299, 0.587, 0.114));
    \\        blockLuma = asciiDensity(blockLuma);
    \\        vec2 localUV = fract(vec2(pixel) / vec2(blockSz));
    \\        float charPat = 0.0;
    \\        if (blockLuma > 0.8) charPat = 1.0;
    \\        else if (blockLuma > 0.6) charPat = step(0.3, localUV.x) * step(0.3, localUV.y);
    \\        else if (blockLuma > 0.4) charPat = step(0.5, sin(localUV.x * PI) * sin(localUV.y * PI));
    \\        else if (blockLuma > 0.2) charPat = step(0.7, max(abs(localUV.x - 0.5), abs(localUV.y - 0.5)) * 2.0);
    \\        result = mix(result, vec3(charPat), u_ascii_mode);
    \\    }
    \\
    \\    // Film grain effect - adds subtle analog film texture
    \\    if (u_film_grain > 0.0) {
    \\        // Generate noise based on pixel position and frame
    \\        float grain_seed = float(pixel.x + pixel.y * u_width) + float(u_frame) * 0.1;
    \\        float grain_noise = fract(sin(grain_seed * 12.9898 + grain_seed * 78.233) * 43758.5453);
    \\        grain_noise = (grain_noise - 0.5) * 2.0;  // -1 to 1
    \\
    \\        // Make grain stronger in darker areas (like real film)
    \\        float luminance = dot(result, vec3(0.299, 0.587, 0.114));
    \\        float grain_intensity = u_film_grain * (1.0 - luminance * 0.5);
    \\
    \\        // Add colored grain for more realistic film look
    \\        vec3 grain_color = vec3(
    \\            fract(sin(grain_seed * 43.758) * 2345.6789),
    \\            fract(sin(grain_seed * 67.890) * 3456.7890),
    \\            fract(sin(grain_seed * 89.012) * 4567.8901)
    \\        );
    \\        grain_color = (grain_color - 0.5) * 2.0;
    \\
    \\        // Mix luminance grain with subtle color grain
    \\        vec3 grain = mix(vec3(grain_noise), grain_color, 0.3) * grain_intensity * 0.1;
    \\        result += grain;
    \\    }
    \\
    \\    imageStore(outputImage, pixel, vec4(result, 1.0));
    \\}
;
