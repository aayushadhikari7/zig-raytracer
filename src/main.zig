const std = @import("std");
const vec3 = @import("vec3.zig");

const win32 = @cImport({
    @cDefine("WIN32_LEAN_AND_MEAN", "1");
    @cInclude("windows.h");
});

const gl = @cImport({
    @cInclude("GL/gl.h");
});

const Vec3 = vec3.Vec3;
const Color = vec3.Color;

// ============================================================================
// QUALITY SETTINGS - BVH accelerated, high quality!
// ============================================================================
const RENDER_WIDTH: u32 = 1920;
const RENDER_HEIGHT: u32 = 1080;
const WINDOW_SCALE: u32 = 1;
const MAX_DEPTH: u32 = 16;
const SAMPLES_PER_FRAME: u32 = 8;  // Higher = smoother when moving, lower FPS

// OpenGL constants and types
const GLuint = c_uint;
const GLint = c_int;
const GLsizei = c_int;
const GLenum = c_uint;
const GLchar = u8;
const GLboolean = u8;
const GLsizeiptr = isize;

const GL_COMPUTE_SHADER: GLenum = 0x91B9;
const GL_SHADER_STORAGE_BUFFER: GLenum = 0x90D2;
const GL_DYNAMIC_DRAW: GLenum = 0x88E8;
const GL_TEXTURE_2D: GLenum = 0x0DE1;
const GL_RGBA32F: GLenum = 0x8814;
const GL_RGBA: GLenum = 0x1908;
const GL_FLOAT: GLenum = 0x1406;
const GL_READ_WRITE: GLenum = 0x88BA;
const GL_SHADER_IMAGE_ACCESS_BARRIER_BIT: GLenum = 0x00000020;
const GL_TEXTURE_MAG_FILTER: GLenum = 0x2800;
const GL_TEXTURE_MIN_FILTER: GLenum = 0x2801;
const GL_LINEAR: GLenum = 0x2601;
const GL_COMPILE_STATUS: GLenum = 0x8B81;
const GL_LINK_STATUS: GLenum = 0x8B82;
const GL_INFO_LOG_LENGTH: GLenum = 0x8B84;
const GL_TRUE: GLboolean = 1;

// OpenGL function types
const PFNGLCREATESHADERPROC = *const fn (GLenum) callconv(std.builtin.CallingConvention.c) GLuint;
const PFNGLSHADERSOURCEPROC = *const fn (GLuint, GLsizei, [*]const [*]const GLchar, ?[*]const GLint) callconv(std.builtin.CallingConvention.c) void;
const PFNGLCOMPILESHADERPROC = *const fn (GLuint) callconv(std.builtin.CallingConvention.c) void;
const PFNGLGETSHADERIVPROC = *const fn (GLuint, GLenum, *GLint) callconv(std.builtin.CallingConvention.c) void;
const PFNGLGETSHADERINFOLOGPROC = *const fn (GLuint, GLsizei, ?*GLsizei, [*]GLchar) callconv(std.builtin.CallingConvention.c) void;
const PFNGLCREATEPROGRAMPROC = *const fn () callconv(std.builtin.CallingConvention.c) GLuint;
const PFNGLATTACHSHADERPROC = *const fn (GLuint, GLuint) callconv(std.builtin.CallingConvention.c) void;
const PFNGLLINKPROGRAMPROC = *const fn (GLuint) callconv(std.builtin.CallingConvention.c) void;
const PFNGLGETPROGRAMIVPROC = *const fn (GLuint, GLenum, *GLint) callconv(std.builtin.CallingConvention.c) void;
const PFNGLGETPROGRAMINFOLOGPROC = *const fn (GLuint, GLsizei, ?*GLsizei, [*]GLchar) callconv(std.builtin.CallingConvention.c) void;
const PFNGLUSEPROGRAMPROC = *const fn (GLuint) callconv(std.builtin.CallingConvention.c) void;
const PFNGLDELETESHADERPROC = *const fn (GLuint) callconv(std.builtin.CallingConvention.c) void;
const PFNGLDISPATCHCOMPUTEPROC = *const fn (GLuint, GLuint, GLuint) callconv(std.builtin.CallingConvention.c) void;
const PFNGLMEMORYBARRIERPROC = *const fn (GLenum) callconv(std.builtin.CallingConvention.c) void;
const PFNGLBINDIMAGETEXTUREPROC = *const fn (GLuint, GLuint, GLint, GLboolean, GLint, GLenum, GLenum) callconv(std.builtin.CallingConvention.c) void;
const PFNGLGETUNIFORMLOCATIONPROC = *const fn (GLuint, [*]const GLchar) callconv(std.builtin.CallingConvention.c) GLint;
const PFNGLUNIFORM1IPROC = *const fn (GLint, GLint) callconv(std.builtin.CallingConvention.c) void;
const PFNGLUNIFORM1FPROC = *const fn (GLint, f32) callconv(std.builtin.CallingConvention.c) void;
const PFNGLUNIFORM1UIPROC = *const fn (GLint, GLuint) callconv(std.builtin.CallingConvention.c) void;
const PFNGLUNIFORM3FPROC = *const fn (GLint, f32, f32, f32) callconv(std.builtin.CallingConvention.c) void;
const PFNGLGENBUFFERSPROC = *const fn (GLsizei, *GLuint) callconv(std.builtin.CallingConvention.c) void;
const PFNGLBINDBUFFERPROC = *const fn (GLenum, GLuint) callconv(std.builtin.CallingConvention.c) void;
const PFNGLBUFFERDATAPROC = *const fn (GLenum, GLsizeiptr, ?*const anyopaque, GLenum) callconv(std.builtin.CallingConvention.c) void;
const PFNGLBINDBUFFERBASEPROC = *const fn (GLenum, GLuint, GLuint) callconv(std.builtin.CallingConvention.c) void;
const PFNGLACTIVETEXTUREPROC = *const fn (GLenum) callconv(std.builtin.CallingConvention.c) void;

// Global GL function pointers
var glCreateShader: PFNGLCREATESHADERPROC = undefined;
var glShaderSource: PFNGLSHADERSOURCEPROC = undefined;
var glCompileShader: PFNGLCOMPILESHADERPROC = undefined;
var glGetShaderiv: PFNGLGETSHADERIVPROC = undefined;
var glGetShaderInfoLog: PFNGLGETSHADERINFOLOGPROC = undefined;
var glCreateProgram: PFNGLCREATEPROGRAMPROC = undefined;
var glAttachShader: PFNGLATTACHSHADERPROC = undefined;
var glLinkProgram: PFNGLLINKPROGRAMPROC = undefined;
var glGetProgramiv: PFNGLGETPROGRAMIVPROC = undefined;
var glGetProgramInfoLog: PFNGLGETPROGRAMINFOLOGPROC = undefined;
var glUseProgram: PFNGLUSEPROGRAMPROC = undefined;
var glDeleteShader: PFNGLDELETESHADERPROC = undefined;
var glDispatchCompute: PFNGLDISPATCHCOMPUTEPROC = undefined;
var glMemoryBarrier: PFNGLMEMORYBARRIERPROC = undefined;
var glBindImageTexture: PFNGLBINDIMAGETEXTUREPROC = undefined;
var glGetUniformLocation: PFNGLGETUNIFORMLOCATIONPROC = undefined;
var glUniform1i: PFNGLUNIFORM1IPROC = undefined;
var glUniform1f: PFNGLUNIFORM1FPROC = undefined;
var glUniform1ui: PFNGLUNIFORM1UIPROC = undefined;
var glUniform3f: PFNGLUNIFORM3FPROC = undefined;
var glGenBuffers: PFNGLGENBUFFERSPROC = undefined;
var glBindBuffer: PFNGLBINDBUFFERPROC = undefined;
var glBufferData: PFNGLBUFFERDATAPROC = undefined;
var glBindBufferBase: PFNGLBINDBUFFERBASEPROC = undefined;
var glActiveTexture: PFNGLACTIVETEXTUREPROC = undefined;

// WGL types
const HGLRC = *anyopaque;
const PFNWGLCREATECONTEXTATTRIBSARBPROC = *const fn (win32.HDC, ?HGLRC, ?[*]const c_int) callconv(std.builtin.CallingConvention.c) ?HGLRC;
const PFNWGLSWAPINTERVALEXTPROC = *const fn (c_int) callconv(std.builtin.CallingConvention.c) c_int;

extern "opengl32" fn wglCreateContext(win32.HDC) callconv(std.builtin.CallingConvention.c) ?HGLRC;
extern "opengl32" fn wglMakeCurrent(win32.HDC, ?HGLRC) callconv(std.builtin.CallingConvention.c) c_int;
extern "opengl32" fn wglDeleteContext(HGLRC) callconv(std.builtin.CallingConvention.c) c_int;
extern "opengl32" fn wglGetProcAddress([*:0]const u8) callconv(std.builtin.CallingConvention.c) ?*anyopaque;

const WGL_CONTEXT_MAJOR_VERSION_ARB: c_int = 0x2091;
const WGL_CONTEXT_MINOR_VERSION_ARB: c_int = 0x2092;
const WGL_CONTEXT_PROFILE_MASK_ARB: c_int = 0x9126;
const WGL_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB: c_int = 0x00000002;

var g_running: bool = true;
var g_hdc: ?win32.HDC = null;
var g_hglrc: ?HGLRC = null;

var g_keys: [256]bool = [_]bool{false} ** 256;
var g_mouse_captured: bool = false;
var g_mouse_dx: i32 = 0;
var g_mouse_dy: i32 = 0;

var g_camera_pos: Vec3 = Vec3.init(13, 2, 3);
var g_camera_yaw: f32 = 0;
var g_camera_pitch: f32 = -0.15;

// Runtime adjustable settings
var g_fov: f32 = 20.0;
var g_aperture: f32 = 0.0;
var g_focus_dist: f32 = 10.0;
var g_samples_per_frame: u32 = 8;
var g_save_screenshot: bool = false;
var g_show_help: bool = true;

// Effect controls
var g_chromatic_strength: f32 = 0.003;
var g_motion_blur_strength: f32 = 0.5;
var g_bloom_strength: f32 = 0.15;
var g_nee_enabled: bool = true;
var g_roughness_mult: f32 = 1.0;
var g_exposure: f32 = 1.0;
var g_vignette_strength: f32 = 0.15;

fn windowProc(hwnd: win32.HWND, msg: c_uint, wparam: win32.WPARAM, lparam: win32.LPARAM) callconv(std.builtin.CallingConvention.c) win32.LRESULT {
    switch (msg) {
        win32.WM_DESTROY, win32.WM_CLOSE => {
            g_running = false;
            return 0;
        },
        win32.WM_KEYDOWN => {
            if (wparam < 256) g_keys[@intCast(wparam)] = true;
            return 0;
        },
        win32.WM_KEYUP => {
            if (wparam < 256) g_keys[@intCast(wparam)] = false;
            return 0;
        },
        win32.WM_RBUTTONDOWN => {
            g_mouse_captured = !g_mouse_captured;
            if (g_mouse_captured) {
                _ = win32.ShowCursor(0);
                var rect: win32.RECT = undefined;
                _ = win32.GetClientRect(hwnd, &rect);
                _ = win32.ClientToScreen(hwnd, @ptrCast(&rect.left));
                _ = win32.ClientToScreen(hwnd, @ptrCast(&rect.right));
                _ = win32.ClipCursor(&rect);
            } else {
                _ = win32.ShowCursor(1);
                _ = win32.ClipCursor(null);
            }
            return 0;
        },
        win32.WM_MOUSEMOVE => {
            if (g_mouse_captured) {
                const window_width: i32 = @intCast(RENDER_WIDTH * WINDOW_SCALE);
                const window_height: i32 = @intCast(RENDER_HEIGHT * WINDOW_SCALE);
                const cx = @divTrunc(window_width, 2);
                const cy = @divTrunc(window_height, 2);
                const x: i16 = @truncate(lparam & 0xFFFF);
                const y: i16 = @truncate((lparam >> 16) & 0xFFFF);
                g_mouse_dx += x - cx;
                g_mouse_dy += y - cy;
                var pt = win32.POINT{ .x = cx, .y = cy };
                _ = win32.ClientToScreen(hwnd, &pt);
                _ = win32.SetCursorPos(pt.x, pt.y);
            }
            return 0;
        },
        else => return win32.DefWindowProcA(hwnd, msg, wparam, lparam),
    }
}

fn saveScreenshot(allocator: std.mem.Allocator) !void {
    const width = RENDER_WIDTH;
    const height = RENDER_HEIGHT;
    const pixel_count = width * height;

    // Allocate buffer for pixel data (RGB)
    const pixels = try allocator.alloc(u8, pixel_count * 3);
    defer allocator.free(pixels);

    // Read pixels from framebuffer
    gl.glReadPixels(0, 0, @intCast(width), @intCast(height), gl.GL_RGB, gl.GL_UNSIGNED_BYTE, pixels.ptr);

    // Generate filename with timestamp
    const timestamp = std.time.timestamp();
    var filename_buf: [64]u8 = undefined;
    const filename = std.fmt.bufPrintZ(&filename_buf, "screenshot_{d}.bmp", .{timestamp}) catch "screenshot.bmp";

    // Create BMP file
    const file = std.fs.cwd().createFile(filename, .{}) catch |err| {
        std.debug.print("Failed to create screenshot file: {}\n", .{err});
        return;
    };
    defer file.close();

    // BMP Header (14 bytes)
    const file_size: u32 = 54 + @as(u32, @intCast(pixel_count * 3));
    const bmp_header = [14]u8{
        'B', 'M',                                          // Signature
        @truncate(file_size), @truncate(file_size >> 8),   // File size
        @truncate(file_size >> 16), @truncate(file_size >> 24),
        0, 0, 0, 0,                                        // Reserved
        54, 0, 0, 0,                                       // Pixel data offset
    };

    // DIB Header (40 bytes)
    const w: u32 = width;
    const h: u32 = height;
    const dib_header = [40]u8{
        40, 0, 0, 0,                                       // Header size
        @truncate(w), @truncate(w >> 8), @truncate(w >> 16), @truncate(w >> 24),
        @truncate(h), @truncate(h >> 8), @truncate(h >> 16), @truncate(h >> 24),
        1, 0,                                              // Color planes
        24, 0,                                             // Bits per pixel
        0, 0, 0, 0,                                        // Compression (none)
        0, 0, 0, 0,                                        // Image size (can be 0 for uncompressed)
        0, 0, 0, 0,                                        // Horizontal resolution
        0, 0, 0, 0,                                        // Vertical resolution
        0, 0, 0, 0,                                        // Colors in palette
        0, 0, 0, 0,                                        // Important colors
    };

    file.writeAll(&bmp_header) catch return;
    file.writeAll(&dib_header) catch return;

    // Write pixel data (BMP is bottom-up, RGB -> BGR)
    var row_buf = try allocator.alloc(u8, width * 3);
    defer allocator.free(row_buf);

    var y: u32 = 0;
    while (y < height) : (y += 1) {
        const src_row = pixels[y * width * 3 .. (y + 1) * width * 3];
        // Convert RGB to BGR
        var x: u32 = 0;
        while (x < width) : (x += 1) {
            row_buf[x * 3 + 0] = src_row[x * 3 + 2]; // B
            row_buf[x * 3 + 1] = src_row[x * 3 + 1]; // G
            row_buf[x * 3 + 2] = src_row[x * 3 + 0]; // R
        }
        file.writeAll(row_buf) catch return;
    }

    std.debug.print("Screenshot saved: {s}\n", .{filename});
}

fn loadGLFunctions() bool {
    const load = struct {
        fn f(comptime T: type, name: [*:0]const u8) ?T {
            return @ptrCast(wglGetProcAddress(name));
        }
    }.f;
    glCreateShader = load(PFNGLCREATESHADERPROC, "glCreateShader") orelse return false;
    glShaderSource = load(PFNGLSHADERSOURCEPROC, "glShaderSource") orelse return false;
    glCompileShader = load(PFNGLCOMPILESHADERPROC, "glCompileShader") orelse return false;
    glGetShaderiv = load(PFNGLGETSHADERIVPROC, "glGetShaderiv") orelse return false;
    glGetShaderInfoLog = load(PFNGLGETSHADERINFOLOGPROC, "glGetShaderInfoLog") orelse return false;
    glCreateProgram = load(PFNGLCREATEPROGRAMPROC, "glCreateProgram") orelse return false;
    glAttachShader = load(PFNGLATTACHSHADERPROC, "glAttachShader") orelse return false;
    glLinkProgram = load(PFNGLLINKPROGRAMPROC, "glLinkProgram") orelse return false;
    glGetProgramiv = load(PFNGLGETPROGRAMIVPROC, "glGetProgramiv") orelse return false;
    glGetProgramInfoLog = load(PFNGLGETPROGRAMINFOLOGPROC, "glGetProgramInfoLog") orelse return false;
    glUseProgram = load(PFNGLUSEPROGRAMPROC, "glUseProgram") orelse return false;
    glDeleteShader = load(PFNGLDELETESHADERPROC, "glDeleteShader") orelse return false;
    glDispatchCompute = load(PFNGLDISPATCHCOMPUTEPROC, "glDispatchCompute") orelse return false;
    glMemoryBarrier = load(PFNGLMEMORYBARRIERPROC, "glMemoryBarrier") orelse return false;
    glBindImageTexture = load(PFNGLBINDIMAGETEXTUREPROC, "glBindImageTexture") orelse return false;
    glGetUniformLocation = load(PFNGLGETUNIFORMLOCATIONPROC, "glGetUniformLocation") orelse return false;
    glUniform1i = load(PFNGLUNIFORM1IPROC, "glUniform1i") orelse return false;
    glUniform1f = load(PFNGLUNIFORM1FPROC, "glUniform1f") orelse return false;
    glUniform1ui = load(PFNGLUNIFORM1UIPROC, "glUniform1ui") orelse return false;
    glUniform3f = load(PFNGLUNIFORM3FPROC, "glUniform3f") orelse return false;
    glGenBuffers = load(PFNGLGENBUFFERSPROC, "glGenBuffers") orelse return false;
    glBindBuffer = load(PFNGLBINDBUFFERPROC, "glBindBuffer") orelse return false;
    glBufferData = load(PFNGLBUFFERDATAPROC, "glBufferData") orelse return false;
    glBindBufferBase = load(PFNGLBINDBUFFERBASEPROC, "glBindBufferBase") orelse return false;
    glActiveTexture = load(PFNGLACTIVETEXTUREPROC, "glActiveTexture") orelse return false;
    return true;
}

// ============================================================================
// COMPUTE SHADER WITH BVH TRAVERSAL
// ============================================================================
const compute_shader_source: [*:0]const u8 =
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
    \\
    \\#define MAX_DEPTH 16
    \\#define BVH_STACK_SIZE 64
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
    \\vec3 random_in_unit_sphere() {
    \\    for (int i = 0; i < 100; i++) {
    \\        vec3 p = vec3(rand() * 2.0 - 1.0, rand() * 2.0 - 1.0, rand() * 2.0 - 1.0);
    \\        if (dot(p, p) < 1.0) return p;
    \\    }
    \\    return vec3(0.0);
    \\}
    \\
    \\vec3 random_unit_vector() {
    \\    return normalize(random_in_unit_sphere());
    \\}
    \\
    \\vec3 random_in_unit_disk() {
    \\    for (int i = 0; i < 100; i++) {
    \\        vec3 p = vec3(rand() * 2.0 - 1.0, rand() * 2.0 - 1.0, 0.0);
    \\        if (dot(p, p) < 1.0) return p;
    \\    }
    \\    return vec3(0.0);
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
    \\struct HitRecord {
    \\    vec3 point;
    \\    vec3 normal;
    \\    float t;
    \\    bool front_face;
    \\    int sphere_idx;
    \\    bool is_triangle;
    \\};
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
    \\    return true;
    \\}
    \\
    \\// Test all triangles (simple linear traversal for now)
    \\bool hit_triangles(vec3 ro, vec3 rd, float t_min, float t_max, inout HitRecord rec, inout float closest) {
    \\    bool hit_anything = false;
    \\    HitRecord temp_rec;
    \\
    \\    for (int i = 0; i < num_triangles; i++) {
    \\        if (hit_triangle(ro, rd, i, t_min, closest, temp_rec)) {
    \\            hit_anything = true;
    \\            closest = temp_rec.t;
    \\            rec = temp_rec;
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
    \\
    \\        if (!hit_aabb(ro, inv_rd, node.aabb_min, node.aabb_max, closest)) {
    \\            continue;
    \\        }
    \\
    \\        if (node.left_child == -1) {
    \\            // Leaf node - test sphere
    \\            int sphere_idx = node.right_child;
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
    \\    // Also check triangles
    \\    if (hit_triangles(ro, rd, t_min, closest, rec, closest)) {
    \\        hit_anything = true;
    \\    }
    \\
    \\    return hit_anything;
    \\}
    \\
    \\float reflectance(float cosine, float ior) {
    \\    float r0 = (1.0 - ior) / (1.0 + ior);
    \\    r0 = r0 * r0;
    \\    return r0 + (1.0 - r0) * pow(1.0 - cosine, 5.0);
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
    \\// Beautiful HDR sky with sun
    \\vec3 getSky(vec3 rd) {
    \\    vec3 sun_dir = normalize(vec3(0.5, 0.4, -0.6));
    \\    float sun = max(0.0, dot(rd, sun_dir));
    \\
    \\    // Sky gradient - warm horizon, blue zenith
    \\    float t = 0.5 * (rd.y + 1.0);
    \\    vec3 sky = mix(vec3(0.9, 0.85, 0.8), vec3(0.4, 0.6, 1.0), pow(t, 0.5));
    \\
    \\    // Sun glow
    \\    sky += vec3(1.0, 0.9, 0.7) * pow(sun, 64.0) * 2.0;
    \\    sky += vec3(1.0, 0.7, 0.4) * pow(sun, 8.0) * 0.3;
    \\
    \\    return sky * 1.2;
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
    \\    return direct;
    \\}
    \\
    \\vec3 trace(vec3 ro, vec3 rd) {
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
    \\            if (rec.is_triangle) {
    \\                Triangle tri = triangles[rec.sphere_idx];
    \\                mat_type = tri.mat_type;
    \\                albedo = tri.albedo;
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
    \\                color *= albedo;
    \\            }
    \\            // Metal with GGX microfacet BRDF
    \\            else if (mat_type == 1) {
    \\                vec3 V = -rd;
    \\                vec3 N = rec.normal;
    \\                float roughness = max(fuzz_or_roughness * u_roughness_mult, 0.04);
    \\
    \\                // GGX importance sampling for reflection direction
    \\                vec2 Xi = vec2(rand(), rand());
    \\                vec3 H = ImportanceSampleGGX(Xi, N, roughness);
    \\                vec3 L = reflect(-V, H);
    \\
    \\                float NdotL = dot(N, L);
    \\                if (NdotL <= 0.0) break;
    \\
    \\                float NdotV = max(dot(N, V), 0.0);
    \\                float NdotH = max(dot(N, H), 0.0);
    \\                float VdotH = max(dot(V, H), 0.0);
    \\
    \\                // Cook-Torrance BRDF
    \\                vec3 F0 = albedo;  // Metal uses albedo as F0
    \\                vec3 F = FresnelSchlick(VdotH, F0);
    \\                float G = GeometrySmith(N, V, L, roughness);
    \\
    \\                // Importance sampling weight
    \\                vec3 weight = F * G * VdotH / max(NdotH * NdotV, 0.001);
    \\
    \\                rd = L;
    \\                ro = rec.point + rec.normal * 0.001;
    \\                color *= weight;
    \\            }
    \\            // Dielectric (glass)
    \\            else if (mat_type == 2) {
    \\                float ri = rec.front_face ? (1.0 / ior) : ior;
    \\                vec3 unit_dir = normalize(rd);
    \\                float cos_theta = min(dot(-unit_dir, rec.normal), 1.0);
    \\                float sin_theta = sqrt(1.0 - cos_theta * cos_theta);
    \\                bool cannot_refract = ri * sin_theta > 1.0;
    \\                if (cannot_refract || reflectance(cos_theta, ri) > rand()) {
    \\                    rd = reflect(unit_dir, rec.normal);
    \\                    ro = rec.point + rec.normal * 0.001;
    \\                } else {
    \\                    rd = refract(unit_dir, rec.normal, ri);
    \\                    ro = rec.point - rec.normal * 0.001;
    \\                }
    \\            }
    \\        } else {
    \\            light += color * getSky(rd);
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
    \\        vec3 disk = random_in_unit_disk();
    \\        vec3 offset = (u_camera_right * disk.x + u_camera_up * disk.y) * u_aperture;
    \\        ro = u_camera_pos + offset;
    \\        rd = normalize(focus_point - ro);
    \\    }
    \\
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
    \\    // Chromatic aberration - sample at offset positions for each channel
    \\    vec2 center = vec2(u_width, u_height) * 0.5;
    \\    vec2 pixelVec = vec2(pixel) - center;
    \\    float dist = length(pixelVec) / length(center);
    \\    float chromaStrength = u_chromatic * dist * dist;  // Stronger at edges
    \\
    \\    vec2 redOffset = pixelVec * (1.0 + chromaStrength);
    \\    vec2 blueOffset = pixelVec * (1.0 - chromaStrength);
    \\
    \\    ivec2 redPixel = ivec2(center + redOffset);
    \\    ivec2 bluePixel = ivec2(center + blueOffset);
    \\
    \\    // Clamp to image bounds
    \\    redPixel = clamp(redPixel, ivec2(0), ivec2(u_width - 1, u_height - 1));
    \\    bluePixel = clamp(bluePixel, ivec2(0), ivec2(u_width - 1, u_height - 1));
    \\
    \\    vec4 redAccum = imageLoad(accumImage, redPixel);
    \\    vec4 blueAccum = imageLoad(accumImage, bluePixel);
    \\
    \\    result.r = redAccum.r / max(redAccum.a, 1.0);
    \\    result.b = blueAccum.b / max(blueAccum.a, 1.0);
    \\
    \\    // Motion blur based on camera movement
    \\    vec3 cameraDelta = u_camera_pos - u_prev_camera_pos;
    \\    vec3 forwardDelta = u_camera_forward - u_prev_camera_forward;
    \\    float motionMag = length(cameraDelta) + length(forwardDelta) * 2.0;
    \\
    \\    if (motionMag > 0.001) {
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
    \\    }
    \\
    \\    // Subtle bloom approximation for bright areas
    \\    float luminance = dot(result, vec3(0.299, 0.587, 0.114));
    \\    float bloom = max(0.0, luminance - 1.0) * u_bloom;
    \\    result += bloom * vec3(1.0, 0.9, 0.8);
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
    \\    imageStore(outputImage, pixel, vec4(result, 1.0));
    \\}
;

// ============================================================================
// GPU DATA STRUCTURES
// ============================================================================
const GPUSphere = extern struct {
    center: [3]f32,
    radius: f32,
    albedo: [3]f32,
    fuzz: f32,
    ior: f32,
    emissive: f32,
    mat_type: i32,
    pad: f32,
};

const GPUTriangle = extern struct {
    v0: [3]f32,
    mat_type: i32,
    v1: [3]f32,
    pad1: f32,
    v2: [3]f32,
    pad2: f32,
    n0: [3]f32,
    pad3: f32,
    n1: [3]f32,
    pad4: f32,
    n2: [3]f32,
    pad5: f32,
    albedo: [3]f32,
    emissive: f32,
};

const GPUBVHNode = extern struct {
    aabb_min: [3]f32,
    left_child: i32,
    aabb_max: [3]f32,
    right_child: i32,
};

// ============================================================================
// OBJ FILE LOADER
// ============================================================================
const ObjMesh = struct {
    triangles: std.ArrayList(GPUTriangle),

    fn deinit(self: *ObjMesh) void {
        self.triangles.deinit();
    }
};

fn loadObj(allocator: std.mem.Allocator, path: []const u8, transform: struct {
    scale: f32 = 1.0,
    offset: Vec3 = Vec3.init(0, 0, 0),
    albedo: [3]f32 = .{ 0.8, 0.8, 0.8 },
    mat_type: i32 = 0,
    emissive: f32 = 0.0,
}) !ObjMesh {
    var mesh = ObjMesh{
        .triangles = std.ArrayList(GPUTriangle).init(allocator),
    };
    errdefer mesh.deinit();

    // Read file
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        std.debug.print("Failed to open OBJ file '{s}': {}\n", .{ path, err });
        return err;
    };
    defer file.close();

    const content = file.readToEndAlloc(allocator, 50 * 1024 * 1024) catch |err| {
        std.debug.print("Failed to read OBJ file: {}\n", .{err});
        return err;
    };
    defer allocator.free(content);

    // Parse vertices and normals
    var vertices = std.ArrayList(Vec3).init(allocator);
    defer vertices.deinit();
    var normals = std.ArrayList(Vec3).init(allocator);
    defer normals.deinit();

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        var parts = std.mem.splitScalar(u8, trimmed, ' ');
        const cmd = parts.next() orelse continue;

        if (std.mem.eql(u8, cmd, "v")) {
            // Vertex position
            const x = std.fmt.parseFloat(f32, parts.next() orelse continue) catch continue;
            const y = std.fmt.parseFloat(f32, parts.next() orelse continue) catch continue;
            const z = std.fmt.parseFloat(f32, parts.next() orelse continue) catch continue;
            try vertices.append(Vec3.init(
                x * transform.scale + transform.offset.x,
                y * transform.scale + transform.offset.y,
                z * transform.scale + transform.offset.z,
            ));
        } else if (std.mem.eql(u8, cmd, "vn")) {
            // Vertex normal
            const x = std.fmt.parseFloat(f32, parts.next() orelse continue) catch continue;
            const y = std.fmt.parseFloat(f32, parts.next() orelse continue) catch continue;
            const z = std.fmt.parseFloat(f32, parts.next() orelse continue) catch continue;
            try normals.append(Vec3.init(x, y, z).normalize());
        } else if (std.mem.eql(u8, cmd, "f")) {
            // Face - collect all vertex indices
            var face_verts: [16]usize = undefined;
            var face_norms: [16]?usize = undefined;
            var face_count: usize = 0;

            while (parts.next()) |face_part| {
                if (face_part.len == 0) continue;
                if (face_count >= 16) break;

                // Parse v/vt/vn or v//vn or v
                var indices = std.mem.splitScalar(u8, face_part, '/');
                const v_str = indices.next() orelse continue;
                const v_idx = (std.fmt.parseInt(usize, v_str, 10) catch continue);
                if (v_idx == 0 or v_idx > vertices.items.len) continue;
                face_verts[face_count] = v_idx - 1;

                // Skip texture coord
                _ = indices.next();

                // Normal index (optional)
                if (indices.next()) |n_str| {
                    if (n_str.len > 0) {
                        const n_idx = std.fmt.parseInt(usize, n_str, 10) catch 0;
                        if (n_idx > 0 and n_idx <= normals.items.len) {
                            face_norms[face_count] = n_idx - 1;
                        } else {
                            face_norms[face_count] = null;
                        }
                    } else {
                        face_norms[face_count] = null;
                    }
                } else {
                    face_norms[face_count] = null;
                }

                face_count += 1;
            }

            // Triangulate face (fan triangulation)
            if (face_count >= 3) {
                var i: usize = 1;
                while (i < face_count - 1) : (i += 1) {
                    const v0 = vertices.items[face_verts[0]];
                    const v1 = vertices.items[face_verts[i]];
                    const v2 = vertices.items[face_verts[i + 1]];

                    // Calculate face normal if not provided
                    const edge1 = v1.sub(v0);
                    const edge2 = v2.sub(v0);
                    const face_normal = edge1.cross(edge2).normalize();

                    const n0 = if (face_norms[0]) |ni| normals.items[ni] else face_normal;
                    const n1 = if (face_norms[i]) |ni| normals.items[ni] else face_normal;
                    const n2 = if (face_norms[i + 1]) |ni| normals.items[ni] else face_normal;

                    try mesh.triangles.append(.{
                        .v0 = .{ v0.x, v0.y, v0.z },
                        .v1 = .{ v1.x, v1.y, v1.z },
                        .v2 = .{ v2.x, v2.y, v2.z },
                        .n0 = .{ n0.x, n0.y, n0.z },
                        .n1 = .{ n1.x, n1.y, n1.z },
                        .n2 = .{ n2.x, n2.y, n2.z },
                        .albedo = transform.albedo,
                        .mat_type = transform.mat_type,
                        .emissive = transform.emissive,
                        .pad1 = 0,
                        .pad2 = 0,
                        .pad3 = 0,
                        .pad4 = 0,
                        .pad5 = 0,
                    });
                }
            }
        }
    }

    std.debug.print("Loaded OBJ '{s}': {} vertices, {} normals, {} triangles\n", .{ path, vertices.items.len, normals.items.len, mesh.triangles.items.len });
    return mesh;
}

fn createIcosphere(triangles: *std.ArrayList(GPUTriangle), center: Vec3, radius: f32, subdivisions: u32, material: struct {
    albedo: [3]f32,
    mat_type: i32,
    emissive: f32,
}) !void {
    // Golden ratio for icosahedron
    const phi: f32 = (1.0 + @sqrt(5.0)) / 2.0;
    const a: f32 = 1.0;
    const b: f32 = 1.0 / phi;

    // Icosahedron vertices (normalized)
    const base_verts = [12]Vec3{
        Vec3.init(0, b, -a).normalize(),
        Vec3.init(b, a, 0).normalize(),
        Vec3.init(-b, a, 0).normalize(),
        Vec3.init(0, b, a).normalize(),
        Vec3.init(0, -b, a).normalize(),
        Vec3.init(-a, 0, b).normalize(),
        Vec3.init(0, -b, -a).normalize(),
        Vec3.init(a, 0, -b).normalize(),
        Vec3.init(a, 0, b).normalize(),
        Vec3.init(-a, 0, -b).normalize(),
        Vec3.init(b, -a, 0).normalize(),
        Vec3.init(-b, -a, 0).normalize(),
    };

    // Icosahedron faces (20 triangles)
    const faces = [20][3]u8{
        .{ 2, 1, 0 },  .{ 1, 2, 3 },  .{ 5, 4, 3 },  .{ 4, 8, 3 },
        .{ 7, 6, 0 },  .{ 6, 9, 0 },  .{ 11, 10, 4 }, .{ 10, 11, 6 },
        .{ 9, 5, 2 },  .{ 5, 9, 11 }, .{ 8, 7, 1 },  .{ 7, 8, 10 },
        .{ 2, 5, 3 },  .{ 8, 1, 3 },  .{ 9, 2, 0 },  .{ 1, 7, 0 },
        .{ 11, 9, 6 }, .{ 7, 10, 6 }, .{ 5, 11, 4 }, .{ 10, 8, 4 },
    };

    // Helper to add a subdivided triangle
    const SubdivideHelper = struct {
        fn subdivide(tris: *std.ArrayList(GPUTriangle), v0: Vec3, v1: Vec3, v2: Vec3, depth: u32, c: Vec3, r: f32, mat: struct {
            albedo: [3]f32,
            mat_type: i32,
            emissive: f32,
        }) !void {
            if (depth == 0) {
                // Add final triangle
                const p0 = c.add(v0.scale(r));
                const p1 = c.add(v1.scale(r));
                const p2 = c.add(v2.scale(r));
                try tris.append(.{
                    .v0 = .{ p0.x, p0.y, p0.z },
                    .v1 = .{ p1.x, p1.y, p1.z },
                    .v2 = .{ p2.x, p2.y, p2.z },
                    .n0 = .{ v0.x, v0.y, v0.z },
                    .n1 = .{ v1.x, v1.y, v1.z },
                    .n2 = .{ v2.x, v2.y, v2.z },
                    .albedo = mat.albedo,
                    .mat_type = mat.mat_type,
                    .emissive = mat.emissive,
                    .pad1 = 0,
                    .pad2 = 0,
                    .pad3 = 0,
                    .pad4 = 0,
                    .pad5 = 0,
                });
            } else {
                // Subdivide
                const m01 = v0.add(v1).scale(0.5).normalize();
                const m12 = v1.add(v2).scale(0.5).normalize();
                const m20 = v2.add(v0).scale(0.5).normalize();
                try subdivide(tris, v0, m01, m20, depth - 1, c, r, mat);
                try subdivide(tris, m01, v1, m12, depth - 1, c, r, mat);
                try subdivide(tris, m20, m12, v2, depth - 1, c, r, mat);
                try subdivide(tris, m01, m12, m20, depth - 1, c, r, mat);
            }
        }
    };

    // Generate all triangles
    for (faces) |face| {
        try SubdivideHelper.subdivide(triangles, base_verts[face[0]], base_verts[face[1]], base_verts[face[2]], subdivisions, center, radius, material);
    }
}

// ============================================================================
// BVH BUILDING
// ============================================================================
const AABB = struct {
    min: Vec3,
    max: Vec3,

    fn empty() AABB {
        return .{
            .min = Vec3.init(std.math.inf(f32), std.math.inf(f32), std.math.inf(f32)),
            .max = Vec3.init(-std.math.inf(f32), -std.math.inf(f32), -std.math.inf(f32)),
        };
    }

    fn expand(self: *AABB, point: Vec3) void {
        self.min.x = @min(self.min.x, point.x);
        self.min.y = @min(self.min.y, point.y);
        self.min.z = @min(self.min.z, point.z);
        self.max.x = @max(self.max.x, point.x);
        self.max.y = @max(self.max.y, point.y);
        self.max.z = @max(self.max.z, point.z);
    }

    fn expandSphere(self: *AABB, center: Vec3, radius: f32) void {
        self.expand(Vec3.init(center.x - radius, center.y - radius, center.z - radius));
        self.expand(Vec3.init(center.x + radius, center.y + radius, center.z + radius));
    }

    fn merge(a: AABB, b: AABB) AABB {
        return .{
            .min = Vec3.init(@min(a.min.x, b.min.x), @min(a.min.y, b.min.y), @min(a.min.z, b.min.z)),
            .max = Vec3.init(@max(a.max.x, b.max.x), @max(a.max.y, b.max.y), @max(a.max.z, b.max.z)),
        };
    }
};

fn buildBVH(
    allocator: std.mem.Allocator,
    spheres: []const GPUSphere,
    indices: []u32,
    nodes: *std.ArrayList(GPUBVHNode),
) !u32 {
    const node_idx: u32 = @intCast(nodes.items.len);
    try nodes.append(allocator, undefined);

    if (indices.len == 1) {
        // Leaf node
        const s = spheres[indices[0]];
        var aabb = AABB.empty();
        aabb.expandSphere(Vec3.init(s.center[0], s.center[1], s.center[2]), s.radius);

        nodes.items[node_idx] = .{
            .aabb_min = .{ aabb.min.x, aabb.min.y, aabb.min.z },
            .left_child = -1,
            .aabb_max = .{ aabb.max.x, aabb.max.y, aabb.max.z },
            .right_child = @intCast(indices[0]),
        };
        return node_idx;
    }

    // Compute bounding box of all spheres
    var bounds = AABB.empty();
    for (indices) |idx| {
        const s = spheres[idx];
        bounds.expandSphere(Vec3.init(s.center[0], s.center[1], s.center[2]), s.radius);
    }

    // Find longest axis
    const extent = Vec3.init(
        bounds.max.x - bounds.min.x,
        bounds.max.y - bounds.min.y,
        bounds.max.z - bounds.min.z,
    );
    var axis: usize = 0;
    if (extent.y > extent.x) axis = 1;
    if (extent.z > (if (axis == 0) extent.x else extent.y)) axis = 2;

    // Sort by axis
    const SortContext = struct {
        spheres: []const GPUSphere,
        axis: usize,
    };
    const ctx = SortContext{ .spheres = spheres, .axis = axis };

    std.mem.sort(u32, indices, ctx, struct {
        fn lessThan(c: SortContext, a: u32, b: u32) bool {
            const ca = c.spheres[a].center[c.axis];
            const cb = c.spheres[b].center[c.axis];
            return ca < cb;
        }
    }.lessThan);

    // Split in half
    const mid = indices.len / 2;
    const left_idx = try buildBVH(allocator, spheres, indices[0..mid], nodes);
    const right_idx = try buildBVH(allocator, spheres, indices[mid..], nodes);

    // Merge bounds from children
    const left_node = nodes.items[left_idx];
    const right_node = nodes.items[right_idx];
    const left_aabb = AABB{
        .min = Vec3.init(left_node.aabb_min[0], left_node.aabb_min[1], left_node.aabb_min[2]),
        .max = Vec3.init(left_node.aabb_max[0], left_node.aabb_max[1], left_node.aabb_max[2]),
    };
    const right_aabb = AABB{
        .min = Vec3.init(right_node.aabb_min[0], right_node.aabb_min[1], right_node.aabb_min[2]),
        .max = Vec3.init(right_node.aabb_max[0], right_node.aabb_max[1], right_node.aabb_max[2]),
    };
    const merged = AABB.merge(left_aabb, right_aabb);

    nodes.items[node_idx] = .{
        .aabb_min = .{ merged.min.x, merged.min.y, merged.min.z },
        .left_child = @intCast(left_idx),
        .aabb_max = .{ merged.max.x, merged.max.y, merged.max.z },
        .right_child = @intCast(right_idx),
    };

    return node_idx;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const hinstance = win32.GetModuleHandleA(null);
    const wc = win32.WNDCLASSEXA{
        .cbSize = @sizeOf(win32.WNDCLASSEXA),
        .style = win32.CS_HREDRAW | win32.CS_VREDRAW | win32.CS_OWNDC,
        .lpfnWndProc = @ptrCast(&windowProc),
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = hinstance,
        .hIcon = null,
        .hCursor = win32.LoadCursorA(null, @ptrFromInt(32512)),
        .hbrBackground = null,
        .lpszMenuName = null,
        .lpszClassName = "ZigRaytracerClass",
        .hIconSm = null,
    };
    _ = win32.RegisterClassExA(&wc);

    const window_width: i32 = @intCast(RENDER_WIDTH * WINDOW_SCALE);
    const window_height: i32 = @intCast(RENDER_HEIGHT * WINDOW_SCALE);
    var rect = win32.RECT{ .left = 0, .top = 0, .right = window_width, .bottom = window_height };
    _ = win32.AdjustWindowRect(&rect, win32.WS_OVERLAPPEDWINDOW, 0);

    const hwnd = win32.CreateWindowExA(0, "ZigRaytracerClass", "Zig GPU Raytracer + BVH", win32.WS_OVERLAPPEDWINDOW | win32.WS_VISIBLE, win32.CW_USEDEFAULT, win32.CW_USEDEFAULT, rect.right - rect.left, rect.bottom - rect.top, null, null, hinstance, null);
    if (hwnd == null) {
        std.debug.print("Failed to create window\n", .{});
        return;
    }

    const hdc = win32.GetDC(hwnd);
    g_hdc = hdc;

    const pfd = win32.PIXELFORMATDESCRIPTOR{
        .nSize = @sizeOf(win32.PIXELFORMATDESCRIPTOR),
        .nVersion = 1,
        .dwFlags = 0x00000001 | 0x00000004 | 0x00000020,
        .iPixelType = 0,
        .cColorBits = 32,
        .cRedBits = 0, .cRedShift = 0, .cGreenBits = 0, .cGreenShift = 0, .cBlueBits = 0, .cBlueShift = 0,
        .cAlphaBits = 8, .cAlphaShift = 0, .cAccumBits = 0, .cAccumRedBits = 0, .cAccumGreenBits = 0, .cAccumBlueBits = 0, .cAccumAlphaBits = 0,
        .cDepthBits = 24, .cStencilBits = 8, .cAuxBuffers = 0, .iLayerType = 0, .bReserved = 0, .dwLayerMask = 0, .dwVisibleMask = 0, .dwDamageMask = 0,
    };

    const pixel_format = win32.ChoosePixelFormat(hdc, &pfd);
    _ = win32.SetPixelFormat(hdc, pixel_format, &pfd);

    const temp_context = wglCreateContext(hdc);
    _ = wglMakeCurrent(hdc, temp_context);
    const wglCreateContextAttribsARB: ?PFNWGLCREATECONTEXTATTRIBSARBPROC = @ptrCast(wglGetProcAddress("wglCreateContextAttribsARB"));
    const wglSwapIntervalEXT: ?PFNWGLSWAPINTERVALEXTPROC = @ptrCast(wglGetProcAddress("wglSwapIntervalEXT"));
    _ = wglMakeCurrent(null, null);
    _ = wglDeleteContext(temp_context.?);

    if (wglCreateContextAttribsARB) |createContext| {
        const attribs = [_]c_int{ WGL_CONTEXT_MAJOR_VERSION_ARB, 4, WGL_CONTEXT_MINOR_VERSION_ARB, 3, WGL_CONTEXT_PROFILE_MASK_ARB, WGL_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB, 0 };
        g_hglrc = createContext(hdc, null, &attribs);
    }
    if (g_hglrc == null) {
        std.debug.print("Failed to create GL 4.3 context\n", .{});
        return;
    }
    _ = wglMakeCurrent(hdc, g_hglrc);
    if (wglSwapIntervalEXT) |swapInterval| _ = swapInterval(0);
    if (!loadGLFunctions()) {
        std.debug.print("Failed to load GL functions\n", .{});
        return;
    }
    std.debug.print("OpenGL context created successfully\n", .{});

    const compute_program = createComputeShader() orelse {
        std.debug.print("Failed to create compute shader\n", .{});
        return;
    };

    var output_texture: GLuint = 0;
    var accum_texture: GLuint = 0;
    gl.glGenTextures(1, &output_texture);
    gl.glGenTextures(1, &accum_texture);

    gl.glBindTexture(GL_TEXTURE_2D, output_texture);
    gl.glTexImage2D(GL_TEXTURE_2D, 0, @intCast(GL_RGBA32F), @intCast(RENDER_WIDTH), @intCast(RENDER_HEIGHT), 0, GL_RGBA, GL_FLOAT, null);
    gl.glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, @intCast(GL_LINEAR));
    gl.glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, @intCast(GL_LINEAR));

    gl.glBindTexture(GL_TEXTURE_2D, accum_texture);
    gl.glTexImage2D(GL_TEXTURE_2D, 0, @intCast(GL_RGBA32F), @intCast(RENDER_WIDTH), @intCast(RENDER_HEIGHT), 0, GL_RGBA, GL_FLOAT, null);
    gl.glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, @intCast(GL_LINEAR));
    gl.glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, @intCast(GL_LINEAR));

    // Create spheres
    var spheres: std.ArrayList(GPUSphere) = .empty;
    defer spheres.deinit(allocator);
    try setupScene(allocator, &spheres);

    // Build BVH
    var indices = try allocator.alloc(u32, spheres.items.len);
    defer allocator.free(indices);
    for (0..spheres.items.len) |i| indices[i] = @intCast(i);

    var bvh_nodes: std.ArrayList(GPUBVHNode) = .empty;
    defer bvh_nodes.deinit(allocator);
    _ = try buildBVH(allocator, spheres.items, indices, &bvh_nodes);

    std.debug.print("Scene: {} spheres, {} BVH nodes\n", .{ spheres.items.len, bvh_nodes.items.len });

    // Upload sphere buffer
    var sphere_ssbo: GLuint = 0;
    glGenBuffers(1, &sphere_ssbo);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, sphere_ssbo);
    const sphere_header_size = 16;
    const sphere_buffer_size = sphere_header_size + spheres.items.len * @sizeOf(GPUSphere);
    const sphere_buffer_data = try allocator.alloc(u8, sphere_buffer_size);
    defer allocator.free(sphere_buffer_data);
    const num_spheres: i32 = @intCast(spheres.items.len);
    @memcpy(sphere_buffer_data[0..4], std.mem.asBytes(&num_spheres));
    @memset(sphere_buffer_data[4..16], 0);
    @memcpy(sphere_buffer_data[sphere_header_size..], std.mem.sliceAsBytes(spheres.items));
    glBufferData(GL_SHADER_STORAGE_BUFFER, @intCast(sphere_buffer_size), sphere_buffer_data.ptr, GL_DYNAMIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 2, sphere_ssbo);

    // Upload BVH buffer
    var bvh_ssbo: GLuint = 0;
    glGenBuffers(1, &bvh_ssbo);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, bvh_ssbo);
    const bvh_header_size = 16;
    const bvh_buffer_size = bvh_header_size + bvh_nodes.items.len * @sizeOf(GPUBVHNode);
    const bvh_buffer_data = try allocator.alloc(u8, bvh_buffer_size);
    defer allocator.free(bvh_buffer_data);
    const num_nodes: i32 = @intCast(bvh_nodes.items.len);
    @memcpy(bvh_buffer_data[0..4], std.mem.asBytes(&num_nodes));
    @memset(bvh_buffer_data[4..16], 0);
    @memcpy(bvh_buffer_data[bvh_header_size..], std.mem.sliceAsBytes(bvh_nodes.items));
    glBufferData(GL_SHADER_STORAGE_BUFFER, @intCast(bvh_buffer_size), bvh_buffer_data.ptr, GL_DYNAMIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 3, bvh_ssbo);

    // Load triangle meshes - try OBJ files first, fallback to procedural
    var triangles = std.ArrayList(GPUTriangle).init(allocator);
    defer triangles.deinit();

    // Try loading OBJ files from models folder
    // Model 1: Golden torus (center)
    if (loadObj(allocator, "models/torus.obj", .{
        .scale = 0.8,
        .offset = Vec3.init(0.0, 1.2, -5.0),
        .albedo = .{ 1.0, 0.84, 0.0 }, // Gold
        .mat_type = 1, // Metal
    })) |mesh| {
        defer @constCast(&mesh).deinit();
        try triangles.appendSlice(mesh.triangles.items);
        std.debug.print("Loaded torus.obj\n", .{});
    } else |_| {}

    // Model 2: Glass diamond (left)
    if (loadObj(allocator, "models/diamond.obj", .{
        .scale = 0.6,
        .offset = Vec3.init(-2.5, 1.0, -4.0),
        .albedo = .{ 0.95, 0.95, 1.0 }, // Slight blue tint
        .mat_type = 2, // Glass
    })) |mesh| {
        defer @constCast(&mesh).deinit();
        try triangles.appendSlice(mesh.triangles.items);
        std.debug.print("Loaded diamond.obj\n", .{});
    } else |_| {}

    // Model 3: Red diffuse pyramid (right)
    if (loadObj(allocator, "models/pyramid.obj", .{
        .scale = 0.7,
        .offset = Vec3.init(2.5, 0.7, -4.0),
        .albedo = .{ 0.85, 0.15, 0.1 }, // Red
        .mat_type = 0, // Diffuse
    })) |mesh| {
        defer @constCast(&mesh).deinit();
        try triangles.appendSlice(mesh.triangles.items);
        std.debug.print("Loaded pyramid.obj\n", .{});
    } else |_| {}

    // Model 4: Chrome cube (back)
    if (loadObj(allocator, "models/cube.obj", .{
        .scale = 1.2,
        .offset = Vec3.init(0.0, 0.6, -8.0),
        .albedo = .{ 0.95, 0.95, 0.97 }, // Chrome
        .mat_type = 1, // Metal
    })) |mesh| {
        defer @constCast(&mesh).deinit();
        try triangles.appendSlice(mesh.triangles.items);
        std.debug.print("Loaded cube.obj\n", .{});
    } else |_| {}

    // Fallback: if no models loaded, create procedural shapes
    if (triangles.items.len == 0) {
        std.debug.print("No OBJ files found, creating procedural meshes\n", .{});

        // Gold icosphere (center)
        try createIcosphere(&triangles, Vec3.init(0.0, 1.5, -5.0), 1.0, 2, .{
            .albedo = .{ 1.0, 0.84, 0.0 },
            .mat_type = 1,
            .emissive = 0.0,
        });

        // Glass icosphere (left)
        try createIcosphere(&triangles, Vec3.init(-2.5, 1.0, -4.0), 0.8, 2, .{
            .albedo = .{ 1.0, 1.0, 1.0 },
            .mat_type = 2,
            .emissive = 0.0,
        });

        // Red diffuse icosphere (right)
        try createIcosphere(&triangles, Vec3.init(2.5, 1.0, -4.0), 0.8, 2, .{
            .albedo = .{ 0.8, 0.2, 0.2 },
            .mat_type = 0,
            .emissive = 0.0,
        });
    }

    std.debug.print("Scene: {} triangles\n", .{triangles.items.len});

    // Upload triangle buffer
    var triangle_ssbo: GLuint = 0;
    glGenBuffers(1, &triangle_ssbo);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, triangle_ssbo);
    const tri_header_size = 16;
    const tri_buffer_size = tri_header_size + triangles.items.len * @sizeOf(GPUTriangle);
    const tri_buffer_data = try allocator.alloc(u8, tri_buffer_size);
    defer allocator.free(tri_buffer_data);
    const num_triangles: i32 = @intCast(triangles.items.len);
    @memcpy(tri_buffer_data[0..4], std.mem.asBytes(&num_triangles));
    @memset(tri_buffer_data[4..16], 0);
    @memcpy(tri_buffer_data[tri_header_size..], std.mem.sliceAsBytes(triangles.items));
    glBufferData(GL_SHADER_STORAGE_BUFFER, @intCast(tri_buffer_size), tri_buffer_data.ptr, GL_DYNAMIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 4, triangle_ssbo);

    const u_camera_pos_loc = glGetUniformLocation(compute_program, "u_camera_pos");
    const u_camera_forward_loc = glGetUniformLocation(compute_program, "u_camera_forward");
    const u_camera_right_loc = glGetUniformLocation(compute_program, "u_camera_right");
    const u_camera_up_loc = glGetUniformLocation(compute_program, "u_camera_up");
    const u_prev_camera_pos_loc = glGetUniformLocation(compute_program, "u_prev_camera_pos");
    const u_prev_camera_forward_loc = glGetUniformLocation(compute_program, "u_prev_camera_forward");
    const u_fov_scale_loc = glGetUniformLocation(compute_program, "u_fov_scale");
    const u_aperture_loc = glGetUniformLocation(compute_program, "u_aperture");
    const u_focus_dist_loc = glGetUniformLocation(compute_program, "u_focus_dist");
    const u_frame_loc = glGetUniformLocation(compute_program, "u_frame");
    const u_sample_loc = glGetUniformLocation(compute_program, "u_sample");
    const u_width_loc = glGetUniformLocation(compute_program, "u_width");
    const u_height_loc = glGetUniformLocation(compute_program, "u_height");
    const u_aspect_loc = glGetUniformLocation(compute_program, "u_aspect");

    // Effect control uniforms
    const u_chromatic_loc = glGetUniformLocation(compute_program, "u_chromatic");
    const u_motion_blur_loc = glGetUniformLocation(compute_program, "u_motion_blur");
    const u_bloom_loc = glGetUniformLocation(compute_program, "u_bloom");
    const u_nee_loc = glGetUniformLocation(compute_program, "u_nee");
    const u_roughness_mult_loc = glGetUniformLocation(compute_program, "u_roughness_mult");
    const u_exposure_loc = glGetUniformLocation(compute_program, "u_exposure");
    const u_vignette_loc = glGetUniformLocation(compute_program, "u_vignette");

    g_camera_yaw = std.math.atan2(@as(f32, -3.0), @as(f32, -13.0));

    // Previous camera state for motion blur
    var prev_camera_pos = g_camera_pos;
    var prev_forward = Vec3.init(0, 0, -1);

    var frame_count: u32 = 0;
    var total_frames: u32 = 0;
    var fps_timer = std.time.milliTimestamp();
    var current_fps: f32 = 0;
    var last_time = std.time.milliTimestamp();
    var title_buf: [256]u8 = undefined;

    while (g_running) {
        var msg: win32.MSG = undefined;
        while (win32.PeekMessageA(&msg, null, 0, 0, win32.PM_REMOVE) != 0) {
            _ = win32.TranslateMessage(&msg);
            _ = win32.DispatchMessageA(&msg);
        }

        const current_time = std.time.milliTimestamp();
        const delta_time: f32 = @as(f32, @floatFromInt(current_time - last_time)) / 1000.0;
        last_time = current_time;

        frame_count += 1;
        if (current_time - fps_timer >= 1000) {
            current_fps = @as(f32, @floatFromInt(frame_count)) * 1000.0 / @as(f32, @floatFromInt(current_time - fps_timer));
            frame_count = 0;
            fps_timer = current_time;
            const nee_str: []const u8 = if (g_nee_enabled) "ON" else "OFF";
            const title = std.fmt.bufPrintZ(&title_buf, "Raytracer | FPS:{d:.0} SPF:{} | C:{d:.3} M:{d:.1} B:{d:.2} E:{d:.1} V:{d:.2} R:{d:.1} NEE:{s}", .{ current_fps, g_samples_per_frame, g_chromatic_strength, g_motion_blur_strength, g_bloom_strength, g_exposure, g_vignette_strength, g_roughness_mult, nee_str }) catch "Raytracer";
            _ = win32.SetWindowTextA(hwnd, title.ptr);
        }

        var camera_moved = false;

        if (g_mouse_captured and (g_mouse_dx != 0 or g_mouse_dy != 0)) {
            g_camera_yaw += @as(f32, @floatFromInt(g_mouse_dx)) * 0.003;
            g_camera_pitch += -@as(f32, @floatFromInt(g_mouse_dy)) * 0.003;
            g_camera_pitch = @max(-1.5, @min(1.5, g_camera_pitch));
            g_mouse_dx = 0;
            g_mouse_dy = 0;
            camera_moved = true;
        }

        const cos_yaw = @cos(g_camera_yaw);
        const sin_yaw = @sin(g_camera_yaw);
        const cos_pitch = @cos(g_camera_pitch);
        const sin_pitch = @sin(g_camera_pitch);

        const forward = Vec3.init(cos_pitch * cos_yaw, sin_pitch, cos_pitch * sin_yaw).normalize();
        const right = Vec3.init(-sin_yaw, 0, cos_yaw).normalize();
        const up = right.cross(forward).normalize();

        const move_speed: f32 = 8.0 * delta_time;
        if (g_keys['W']) { g_camera_pos = g_camera_pos.add(forward.scale(move_speed)); camera_moved = true; }
        if (g_keys['S']) { g_camera_pos = g_camera_pos.add(forward.scale(-move_speed)); camera_moved = true; }
        if (g_keys['A']) { g_camera_pos = g_camera_pos.add(right.scale(-move_speed)); camera_moved = true; }
        if (g_keys['D']) { g_camera_pos = g_camera_pos.add(right.scale(move_speed)); camera_moved = true; }
        if (g_keys[' ']) { g_camera_pos.y += move_speed; camera_moved = true; }
        if (g_keys[win32.VK_SHIFT]) { g_camera_pos.y -= move_speed; camera_moved = true; }
        if (g_keys['R']) {
            g_camera_pos = Vec3.init(13, 2, 3);
            g_camera_yaw = std.math.atan2(@as(f32, -3.0), @as(f32, -13.0));
            g_camera_pitch = -0.15;
            camera_moved = true;
            g_keys['R'] = false;
        }
        if (g_keys[win32.VK_ESCAPE]) g_running = false;

        // === RUNTIME CONTROLS ===
        // F12 - Screenshot
        if (g_keys[win32.VK_F12]) {
            g_save_screenshot = true;
            g_keys[win32.VK_F12] = false;
        }
        // H - Toggle help
        if (g_keys['H']) {
            g_show_help = !g_show_help;
            g_keys['H'] = false;
        }
        // F/G - FOV adjust
        if (g_keys['F']) { g_fov = @max(10.0, g_fov - 2.0); camera_moved = true; g_keys['F'] = false; }
        if (g_keys['G']) { g_fov = @min(120.0, g_fov + 2.0); camera_moved = true; g_keys['G'] = false; }
        // T/Y - Aperture (DOF)
        if (g_keys['T']) { g_aperture = @max(0.0, g_aperture - 0.01); camera_moved = true; g_keys['T'] = false; }
        if (g_keys['Y']) { g_aperture = @min(0.5, g_aperture + 0.01); camera_moved = true; g_keys['Y'] = false; }
        // U/I - Focus distance
        if (g_keys['U']) { g_focus_dist = @max(1.0, g_focus_dist - 1.0); camera_moved = true; g_keys['U'] = false; }
        if (g_keys['I']) { g_focus_dist = @min(100.0, g_focus_dist + 1.0); camera_moved = true; g_keys['I'] = false; }
        // 1-4 - Quality presets
        if (g_keys['1']) { g_samples_per_frame = 2; g_keys['1'] = false; }
        if (g_keys['2']) { g_samples_per_frame = 4; g_keys['2'] = false; }
        if (g_keys['3']) { g_samples_per_frame = 8; g_keys['3'] = false; }
        if (g_keys['4']) { g_samples_per_frame = 16; g_keys['4'] = false; }

        // ============ EFFECT CONTROLS ============
        // C - Chromatic aberration (hold Shift for decrease)
        if (g_keys['C']) {
            if (g_keys[0x10]) { // Shift
                g_chromatic_strength = @max(0.0, g_chromatic_strength - 0.001);
            } else {
                g_chromatic_strength = @min(0.02, g_chromatic_strength + 0.001);
            }
            camera_moved = true; g_keys['C'] = false;
        }
        // M - Motion blur (hold Shift for decrease)
        if (g_keys['M']) {
            if (g_keys[0x10]) {
                g_motion_blur_strength = @max(0.0, g_motion_blur_strength - 0.1);
            } else {
                g_motion_blur_strength = @min(2.0, g_motion_blur_strength + 0.1);
            }
            camera_moved = true; g_keys['M'] = false;
        }
        // B - Bloom (hold Shift for decrease)
        if (g_keys['B']) {
            if (g_keys[0x10]) {
                g_bloom_strength = @max(0.0, g_bloom_strength - 0.05);
            } else {
                g_bloom_strength = @min(1.0, g_bloom_strength + 0.05);
            }
            camera_moved = true; g_keys['B'] = false;
        }
        // N - Toggle NEE (Next Event Estimation)
        if (g_keys['N']) {
            g_nee_enabled = !g_nee_enabled;
            camera_moved = true; g_keys['N'] = false;
        }
        // R - Roughness multiplier (hold Shift for decrease)
        if (g_keys['R']) {
            if (g_keys[0x10]) {
                g_roughness_mult = @max(0.1, g_roughness_mult - 0.1);
            } else {
                g_roughness_mult = @min(3.0, g_roughness_mult + 0.1);
            }
            camera_moved = true; g_keys['R'] = false;
        }
        // E - Exposure (hold Shift for decrease)
        if (g_keys['E']) {
            if (g_keys[0x10]) {
                g_exposure = @max(0.1, g_exposure - 0.1);
            } else {
                g_exposure = @min(5.0, g_exposure + 0.1);
            }
            camera_moved = true; g_keys['E'] = false;
        }
        // V - Vignette (hold Shift for decrease)
        if (g_keys['V']) {
            if (g_keys[0x10]) {
                g_vignette_strength = @max(0.0, g_vignette_strength - 0.05);
            } else {
                g_vignette_strength = @min(0.5, g_vignette_strength + 0.05);
            }
            camera_moved = true; g_keys['V'] = false;
        }

        // Reset accumulation when camera moves
        if (camera_moved) {
            total_frames = 0;
        }
        total_frames += 1;  // Increment ONCE per frame, not per sample

        glUseProgram(compute_program);
        glBindImageTexture(0, output_texture, 0, 0, 0, GL_READ_WRITE, GL_RGBA32F);
        glBindImageTexture(1, accum_texture, 0, 0, 0, GL_READ_WRITE, GL_RGBA32F);

        glUniform3f(u_camera_pos_loc, g_camera_pos.x, g_camera_pos.y, g_camera_pos.z);
        glUniform3f(u_camera_forward_loc, forward.x, forward.y, forward.z);
        glUniform3f(u_camera_right_loc, right.x, right.y, right.z);
        glUniform3f(u_camera_up_loc, up.x, up.y, up.z);
        glUniform3f(u_prev_camera_pos_loc, prev_camera_pos.x, prev_camera_pos.y, prev_camera_pos.z);
        glUniform3f(u_prev_camera_forward_loc, prev_forward.x, prev_forward.y, prev_forward.z);
        glUniform1f(u_fov_scale_loc, 1.0 / @tan(g_fov * std.math.pi / 180.0 / 2.0));
        glUniform1f(u_aperture_loc, g_aperture);
        glUniform1f(u_focus_dist_loc, g_focus_dist);
        glUniform1i(u_width_loc, @intCast(RENDER_WIDTH));
        glUniform1i(u_height_loc, @intCast(RENDER_HEIGHT));
        glUniform1f(u_aspect_loc, @as(f32, @floatFromInt(RENDER_WIDTH)) / @as(f32, @floatFromInt(RENDER_HEIGHT)));
        glUniform1ui(u_frame_loc, total_frames);

        // Effect controls
        glUniform1f(u_chromatic_loc, g_chromatic_strength);
        glUniform1f(u_motion_blur_loc, g_motion_blur_strength);
        glUniform1f(u_bloom_loc, g_bloom_strength);
        glUniform1f(u_nee_loc, if (g_nee_enabled) 1.0 else 0.0);
        glUniform1f(u_roughness_mult_loc, g_roughness_mult);
        glUniform1f(u_exposure_loc, g_exposure);
        glUniform1f(u_vignette_loc, g_vignette_strength);

        const groups_x = (RENDER_WIDTH + 15) / 16;
        const groups_y = (RENDER_HEIGHT + 15) / 16;
        var sample_idx: u32 = 0;
        while (sample_idx < g_samples_per_frame) : (sample_idx += 1) {
            glUniform1ui(u_sample_loc, sample_idx);
            glDispatchCompute(groups_x, groups_y, 1);
            glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);
        }

        gl.glClear(gl.GL_COLOR_BUFFER_BIT);
        gl.glEnable(GL_TEXTURE_2D);
        gl.glBindTexture(GL_TEXTURE_2D, output_texture);
        gl.glBegin(gl.GL_QUADS);
        gl.glTexCoord2f(0, 1); gl.glVertex2f(-1, -1);
        gl.glTexCoord2f(1, 1); gl.glVertex2f(1, -1);
        gl.glTexCoord2f(1, 0); gl.glVertex2f(1, 1);
        gl.glTexCoord2f(0, 0); gl.glVertex2f(-1, 1);
        gl.glEnd();

        _ = win32.SwapBuffers(hdc);

        // Update previous camera state for next frame's motion blur
        prev_camera_pos = g_camera_pos;
        prev_forward = forward;

        // Save screenshot if requested
        if (g_save_screenshot) {
            saveScreenshot(allocator) catch {};
            g_save_screenshot = false;
        }
    }

    if (g_hglrc) |ctx| {
        _ = wglMakeCurrent(null, null);
        _ = wglDeleteContext(ctx);
    }
}

fn createComputeShader() ?GLuint {
    const shader = glCreateShader(GL_COMPUTE_SHADER);
    const sources = [_][*]const GLchar{compute_shader_source};
    glShaderSource(shader, 1, &sources, null);
    glCompileShader(shader);

    var success: GLint = 0;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
    if (success != GL_TRUE) {
        var log_len: GLint = 0;
        glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &log_len);
        if (log_len > 0) {
            var log: [4096]GLchar = undefined;
            glGetShaderInfoLog(shader, 4096, null, &log);
            std.debug.print("Shader compile error: {s}\n", .{log[0..@intCast(log_len)]});
        }
        return null;
    }

    const program = glCreateProgram();
    glAttachShader(program, shader);
    glLinkProgram(program);

    glGetProgramiv(program, GL_LINK_STATUS, &success);
    if (success != GL_TRUE) {
        var log_len: GLint = 0;
        glGetProgramiv(program, GL_INFO_LOG_LENGTH, &log_len);
        if (log_len > 0) {
            var log: [4096]GLchar = undefined;
            glGetProgramInfoLog(program, 4096, null, &log);
            std.debug.print("Program link error: {s}\n", .{log[0..@intCast(log_len)]});
        }
        return null;
    }

    glDeleteShader(shader);
    return program;
}

fn setupScene(allocator: std.mem.Allocator, spheres: *std.ArrayList(GPUSphere)) !void {
    // Ground - subtle checker-like appearance through albedo
    try spheres.append(allocator, .{ .center = .{ 0, -1000, 0 }, .radius = 1000, .albedo = .{ 0.4, 0.4, 0.45 }, .fuzz = 0, .ior = 0, .emissive = 0, .mat_type = 0, .pad = 0 });

    // === HERO SPHERES - The Stars of the Show ===

    // Center: Perfect crystal glass sphere
    try spheres.append(allocator, .{ .center = .{ 0, 1.2, 0 }, .radius = 1.2, .albedo = .{ 1, 1, 1 }, .fuzz = 0, .ior = 1.52, .emissive = 0, .mat_type = 2, .pad = 0 });

    // Left: Rich matte terracotta
    try spheres.append(allocator, .{ .center = .{ -4, 1, 0 }, .radius = 1.0, .albedo = .{ 0.8, 0.3, 0.2 }, .fuzz = 0, .ior = 0, .emissive = 0, .mat_type = 0, .pad = 0 });

    // Right: Polished gold mirror
    try spheres.append(allocator, .{ .center = .{ 4, 1, 0 }, .radius = 1.0, .albedo = .{ 1.0, 0.85, 0.57 }, .fuzz = 0.0, .ior = 0, .emissive = 0, .mat_type = 1, .pad = 0 });

    // === ACCENT SPHERES ===

    // Chrome sphere - perfect mirror
    try spheres.append(allocator, .{ .center = .{ -2, 0.5, 2 }, .radius = 0.5, .albedo = .{ 0.95, 0.95, 0.97 }, .fuzz = 0.0, .ior = 0, .emissive = 0, .mat_type = 1, .pad = 0 });

    // Copper sphere - warm metallic
    try spheres.append(allocator, .{ .center = .{ 2.5, 0.6, 1.5 }, .radius = 0.6, .albedo = .{ 0.95, 0.64, 0.54 }, .fuzz = 0.02, .ior = 0, .emissive = 0, .mat_type = 1, .pad = 0 });

    // Emerald glass
    try spheres.append(allocator, .{ .center = .{ -1.5, 0.4, -2 }, .radius = 0.4, .albedo = .{ 0.8, 1, 0.8 }, .fuzz = 0, .ior = 1.65, .emissive = 0, .mat_type = 2, .pad = 0 });

    // Sapphire glass
    try spheres.append(allocator, .{ .center = .{ 1.5, 0.45, -1.8 }, .radius = 0.45, .albedo = .{ 0.8, 0.85, 1 }, .fuzz = 0, .ior = 1.77, .emissive = 0, .mat_type = 2, .pad = 0 });

    // === DRAMATIC LIGHTING ===

    // Main soft light (sun-like, high up)
    try spheres.append(allocator, .{ .center = .{ 5, 12, -5 }, .radius = 4.0, .albedo = .{ 1.0, 0.95, 0.85 }, .fuzz = 0, .ior = 0, .emissive = 10.0, .mat_type = 3, .pad = 0 });

    // Accent blue light
    try spheres.append(allocator, .{ .center = .{ -8, 4, 3 }, .radius = 1.5, .albedo = .{ 0.4, 0.6, 1.0 }, .fuzz = 0, .ior = 0, .emissive = 6.0, .mat_type = 3, .pad = 0 });

    // Warm rim light
    try spheres.append(allocator, .{ .center = .{ 8, 3, 5 }, .radius = 1.0, .albedo = .{ 1.0, 0.6, 0.3 }, .fuzz = 0, .ior = 0, .emissive = 5.0, .mat_type = 3, .pad = 0 });

    // === MORE SHOWCASE SPHERES ===

    // Brushed steel
    try spheres.append(allocator, .{ .center = .{ -7, 1.3, -2 }, .radius = 1.3, .albedo = .{ 0.7, 0.7, 0.75 }, .fuzz = 0.15, .ior = 0, .emissive = 0, .mat_type = 1, .pad = 0 });

    // Rose gold
    try spheres.append(allocator, .{ .center = .{ 7, 0.9, 2 }, .radius = 0.9, .albedo = .{ 0.92, 0.65, 0.6 }, .fuzz = 0.03, .ior = 0, .emissive = 0, .mat_type = 1, .pad = 0 });

    // Deep blue matte
    try spheres.append(allocator, .{ .center = .{ 0, 0.7, 4 }, .radius = 0.7, .albedo = .{ 0.15, 0.2, 0.5 }, .fuzz = 0, .ior = 0, .emissive = 0, .mat_type = 0, .pad = 0 });

    // Large background glass
    try spheres.append(allocator, .{ .center = .{ -5, 2, -8 }, .radius = 2.0, .albedo = .{ 1, 1, 1 }, .fuzz = 0, .ior = 1.45, .emissive = 0, .mat_type = 2, .pad = 0 });

    // Random spheres - now we can have more with BVH!
    var prng = std.Random.DefaultPrng.init(42);
    var rng = prng.random();

    var a: i32 = -11;
    while (a < 11) : (a += 1) {
        var b: i32 = -11;
        while (b < 11) : (b += 1) {
            const choose_mat = vec3.randomFloat(&rng);
            const center_x = @as(f32, @floatFromInt(a)) + 0.9 * vec3.randomFloat(&rng);
            const center_z = @as(f32, @floatFromInt(b)) + 0.9 * vec3.randomFloat(&rng);
            const center = Vec3.init(center_x, 0.2, center_z);

            if (center.sub(Vec3.init(4, 0.2, 0)).length() < 0.9) continue;
            if (center.sub(Vec3.init(-4, 0.2, 0)).length() < 0.9) continue;
            if (center.sub(Vec3.init(0, 0.2, 0)).length() < 0.9) continue;

            if (choose_mat < 0.65) {
                const albedo = vec3.randomVec3(&rng).mul(vec3.randomVec3(&rng));
                try spheres.append(allocator, .{ .center = .{ center_x, 0.2, center_z }, .radius = 0.2, .albedo = .{ albedo.x, albedo.y, albedo.z }, .fuzz = 0, .ior = 0, .emissive = 0, .mat_type = 0, .pad = 0 });
            } else if (choose_mat < 0.85) {
                const albedo = vec3.randomVec3Range(&rng, 0.5, 1);
                const fuzz = vec3.randomFloatRange(&rng, 0, 0.3);
                try spheres.append(allocator, .{ .center = .{ center_x, 0.2, center_z }, .radius = 0.2, .albedo = .{ albedo.x, albedo.y, albedo.z }, .fuzz = fuzz, .ior = 0, .emissive = 0, .mat_type = 1, .pad = 0 });
            } else if (choose_mat < 0.97) {
                try spheres.append(allocator, .{ .center = .{ center_x, 0.2, center_z }, .radius = 0.2, .albedo = .{ 1, 1, 1 }, .fuzz = 0, .ior = 1.5, .emissive = 0, .mat_type = 2, .pad = 0 });
            } else {
                const light_color = vec3.randomVec3Range(&rng, 0.5, 1);
                try spheres.append(allocator, .{ .center = .{ center_x, 0.2, center_z }, .radius = 0.2, .albedo = .{ light_color.x, light_color.y, light_color.z }, .fuzz = 0, .ior = 0, .emissive = 3.0, .mat_type = 3, .pad = 0 });
            }
        }
    }
}
