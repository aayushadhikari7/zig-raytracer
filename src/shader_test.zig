// Minimal test shader - just outputs a solid color to verify rendering pipeline
pub const compute_shader_source: [*:0]const u8 =
    \\#version 430 core
    \\layout(local_size_x = 16, local_size_y = 16) in;
    \\layout(rgba32f, binding = 0) uniform image2D outputImage;
    \\layout(rgba32f, binding = 1) uniform image2D accumImage;
    \\
    \\uniform uint u_frame;
    \\uniform uint u_sample;
    \\uniform int u_width;
    \\uniform int u_height;
    \\
    \\// Dummy uniforms to match expected bindings
    \\uniform vec3 u_camera_pos;
    \\uniform vec3 u_camera_forward;
    \\uniform vec3 u_camera_right;
    \\uniform vec3 u_camera_up;
    \\uniform vec3 u_prev_camera_pos;
    \\uniform vec3 u_prev_camera_forward;
    \\uniform float u_fov_scale;
    \\uniform float u_aperture;
    \\uniform float u_focus_dist;
    \\uniform float u_aspect;
    \\uniform float u_chromatic;
    \\uniform float u_motion_blur;
    \\uniform float u_bloom;
    \\uniform float u_nee;
    \\uniform float u_roughness_mult;
    \\uniform float u_exposure;
    \\uniform float u_vignette;
    \\uniform float u_normal_strength;
    \\uniform float u_displacement;
    \\uniform float u_denoise;
    \\uniform float u_fog_density;
    \\uniform vec3 u_fog_color;
    \\uniform float u_film_grain;
    \\uniform float u_dispersion;
    \\uniform float u_lens_flare;
    \\uniform float u_iridescence;
    \\uniform float u_anisotropy;
    \\uniform float u_color_temp;
    \\uniform float u_saturation;
    \\uniform float u_scanlines;
    \\uniform float u_tilt_shift;
    \\uniform float u_glitter;
    \\uniform float u_heat_haze;
    \\uniform float u_kaleidoscope;
    \\uniform float u_pixelate;
    \\uniform float u_edge_detect;
    \\uniform float u_halftone;
    \\uniform float u_night_vision;
    \\uniform float u_thermal;
    \\uniform float u_underwater;
    \\uniform float u_rain_drops;
    \\uniform float u_vhs_effect;
    \\uniform float u_anaglyph_3d;
    \\uniform float u_fisheye;
    \\uniform float u_posterize;
    \\uniform float u_sepia;
    \\uniform float u_frosted;
    \\uniform float u_radial_blur;
    \\uniform float u_dither;
    \\uniform float u_holographic;
    \\uniform float u_ascii_mode;
    \\uniform int u_bokeh_shape;
    \\uniform int u_instance_bvh_root;
    \\
    \\// Dummy buffer bindings
    \\layout(std430, binding = 2) buffer SphereBuffer { int num_spheres; int pad1, pad2, pad3; };
    \\layout(std430, binding = 3) buffer BVHBuffer { int num_nodes; int bvh_pad1, bvh_pad2, bvh_pad3; };
    \\layout(std430, binding = 4) buffer TriangleBuffer { int num_triangles; int tri_pad1, tri_pad2, tri_pad3; };
    \\layout(std430, binding = 5) buffer TriBVHBuffer { int num_tri_nodes; int tri_bvh_pad1, tri_bvh_pad2, tri_bvh_pad3; };
    \\layout(std430, binding = 6) buffer AreaLightBuffer { int num_area_lights; int area_pad1, area_pad2, area_pad3; };
    \\layout(std430, binding = 7) buffer InstanceBuffer { int num_instances; int inst_pad1, inst_pad2, inst_pad3; };
    \\layout(std430, binding = 8) buffer InstanceBVHBuffer { int inst_bvh_pad; };
    \\layout(std430, binding = 9) buffer CSGPrimBuffer { int num_csg_prims; int csg_prim_pad1, csg_prim_pad2, csg_prim_pad3; };
    \\layout(std430, binding = 10) buffer CSGObjBuffer { int num_csg_objects; int csg_obj_pad1, csg_obj_pad2, csg_obj_pad3; };
    \\
    \\void main() {
    \\    ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
    \\    if (pixel.x >= u_width || pixel.y >= u_height) return;
    \\
    \\    // Simple gradient test pattern
    \\    float u = float(pixel.x) / float(u_width);
    \\    float v = float(pixel.y) / float(u_height);
    \\
    \\    vec3 color = vec3(u, v, 0.5);
    \\
    \\    // Store directly to output (skip accumulation for test)
    \\    imageStore(outputImage, pixel, vec4(color, 1.0));
    \\    imageStore(accumImage, pixel, vec4(color, 1.0));
    \\}
;
