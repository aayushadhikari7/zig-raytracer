const std = @import("std");
const vec3 = @import("vec3.zig");
const types = @import("types.zig");
const bvh = @import("bvh.zig");
const obj_loader = @import("obj_loader.zig");
const scene = @import("scene.zig");

const GPUSphere = types.GPUSphere;
const GPUTriangle = types.GPUTriangle;
const GPUBVHNode = types.GPUBVHNode;
const GPUAreaLight = types.GPUAreaLight;

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
var g_normal_strength: f32 = 1.5; // Normal map strength
var g_denoise_strength: f32 = 0.5; // Denoising strength (0 = off)
var g_fog_density: f32 = 0.0; // Volumetric fog density (0 = off)
var g_fog_color: [3]f32 = .{ 0.8, 0.85, 0.95 }; // Fog color (blueish)
var g_film_grain: f32 = 0.0; // Film grain strength (0 = off)
var g_bokeh_shape: i32 = 0; // 0=circle, 1=hexagon, 2=star, 3=heart

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
    \\uniform float u_normal_strength;
    \\uniform float u_denoise;
    \\uniform float u_fog_density;
    \\uniform vec3 u_fog_color;
    \\uniform float u_film_grain;
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
    \\// Bokeh shape types: 0=circle, 1=hexagon, 2=star, 3=heart
    \\uniform int u_bokeh_shape;
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
    \\    vec2 uv;
    \\    int texture_id;
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
    \\// Build TBN matrix from normal and UV derivatives
    \\mat3 buildTBN(vec3 N, vec3 pos, vec2 uv) {
    \\    // Compute tangent from world position (approximate)
    \\    vec3 Q1 = dFdx(pos);
    \\    vec3 Q2 = dFdy(pos);
    \\    vec2 st1 = dFdx(uv);
    \\    vec2 st2 = dFdy(uv);
    \\
    \\    vec3 T = normalize(Q1 * st2.y - Q2 * st1.y);
    \\    vec3 B = normalize(cross(N, T));
    \\    T = cross(B, N);
    \\
    \\    return mat3(T, B, N);
    \\}
    \\
    \\// Alternative TBN for compute shader (no dFdx/dFdy)
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
    \\    if (u_denoise > 0.0) {
    \\        result = spatialDenoise(pixel, result, accum.a);
    \\        result = varianceGuidedDenoise(pixel, result, accum.a);
    \\    }
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

// GPU data structures imported from types.zig
// OBJ loader imported from obj_loader.zig

const ObjMesh = obj_loader.ObjMesh;

// Removed loadObj - now in obj_loader.zig
// Lines removed: loadObj, createIcosphere, AABB, buildBVH, buildTriangleBVH

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
    try scene.setupScene(allocator, &spheres);

    // Build BVH
    var indices = try allocator.alloc(u32, spheres.items.len);
    defer allocator.free(indices);
    for (0..spheres.items.len) |i| indices[i] = @intCast(i);

    var bvh_nodes: std.ArrayList(GPUBVHNode) = .empty;
    defer bvh_nodes.deinit(allocator);
    _ = try bvh.buildBVH(allocator, spheres.items, indices, &bvh_nodes);

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
    if (obj_loader.loadObj(allocator, "models/torus.obj", .{
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
    if (obj_loader.loadObj(allocator, "models/diamond.obj", .{
        .scale = 0.6,
        .offset = Vec3.init(-2.5, 1.0, -4.0),
        .albedo = .{ 0.95, 0.95, 1.0 }, // Slight blue tint
        .mat_type = 2, // Glass
    })) |mesh| {
        defer @constCast(&mesh).deinit();
        try triangles.appendSlice(mesh.triangles.items);
        std.debug.print("Loaded diamond.obj\n", .{});
    } else |_| {}

    // Model 3: Brick pyramid (right) - shows brick texture
    if (obj_loader.loadObj(allocator, "models/pyramid.obj", .{
        .scale = 0.7,
        .offset = Vec3.init(2.5, 0.7, -4.0),
        .albedo = .{ 0.85, 0.5, 0.4 }, // Brick base color
        .mat_type = 0, // Diffuse
        .texture_id = 2, // Brick texture
    })) |mesh| {
        defer @constCast(&mesh).deinit();
        try triangles.appendSlice(mesh.triangles.items);
        std.debug.print("Loaded pyramid.obj\n", .{});
    } else |_| {}

    // Model 4: Checker cube (back) - shows checker texture
    if (obj_loader.loadObj(allocator, "models/cube.obj", .{
        .scale = 1.2,
        .offset = Vec3.init(0.0, 0.6, -8.0),
        .albedo = .{ 0.9, 0.9, 0.95 }, // Light gray
        .mat_type = 0, // Diffuse
        .texture_id = 1, // Checker texture
    })) |mesh| {
        defer @constCast(&mesh).deinit();
        try triangles.appendSlice(mesh.triangles.items);
        std.debug.print("Loaded cube.obj\n", .{});
    } else |_| {}

    // Fallback: if no models loaded, create procedural shapes
    if (triangles.items.len == 0) {
        std.debug.print("No OBJ files found, creating procedural meshes\n", .{});

        // Gold icosphere (center)
        try obj_loader.createIcosphere(&triangles, Vec3.init(0.0, 1.5, -5.0), 1.0, 2, .{
            .albedo = .{ 1.0, 0.84, 0.0 },
            .mat_type = 1,
            .emissive = 0.0,
        });

        // Glass icosphere (left)
        try obj_loader.createIcosphere(&triangles, Vec3.init(-2.5, 1.0, -4.0), 0.8, 2, .{
            .albedo = .{ 1.0, 1.0, 1.0 },
            .mat_type = 2,
            .emissive = 0.0,
        });

        // Red diffuse icosphere (right)
        try obj_loader.createIcosphere(&triangles, Vec3.init(2.5, 1.0, -4.0), 0.8, 2, .{
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

    // Build and upload triangle BVH
    var tri_bvh_nodes = std.ArrayList(GPUBVHNode).init(allocator);
    defer tri_bvh_nodes.deinit();

    if (triangles.items.len > 0) {
        var tri_indices = try allocator.alloc(u32, triangles.items.len);
        defer allocator.free(tri_indices);
        for (0..triangles.items.len) |i| {
            tri_indices[i] = @intCast(i);
        }
        _ = try bvh.buildTriangleBVH(allocator, triangles.items, tri_indices, &tri_bvh_nodes);
        std.debug.print("Triangle BVH: {} nodes\n", .{tri_bvh_nodes.items.len});
    }

    var tri_bvh_ssbo: GLuint = 0;
    glGenBuffers(1, &tri_bvh_ssbo);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, tri_bvh_ssbo);
    const tri_bvh_header_size = 16;
    const tri_bvh_buffer_size = tri_bvh_header_size + tri_bvh_nodes.items.len * @sizeOf(GPUBVHNode);
    const tri_bvh_buffer_data = try allocator.alloc(u8, tri_bvh_buffer_size);
    defer allocator.free(tri_bvh_buffer_data);
    const num_tri_nodes: i32 = @intCast(tri_bvh_nodes.items.len);
    @memcpy(tri_bvh_buffer_data[0..4], std.mem.asBytes(&num_tri_nodes));
    @memset(tri_bvh_buffer_data[4..16], 0);
    if (tri_bvh_nodes.items.len > 0) {
        @memcpy(tri_bvh_buffer_data[tri_bvh_header_size..], std.mem.sliceAsBytes(tri_bvh_nodes.items));
    }
    glBufferData(GL_SHADER_STORAGE_BUFFER, @intCast(tri_bvh_buffer_size), tri_bvh_buffer_data.ptr, GL_DYNAMIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 5, tri_bvh_ssbo);

    // Create area lights for soft shadows
    var area_lights = std.ArrayList(GPUAreaLight).init(allocator);
    defer area_lights.deinit();

    // Large overhead rectangular light (studio lighting style)
    try area_lights.append(.{
        .position = .{ -3.0, 8.0, -3.0 },
        .pad0 = 0,
        .u_vec = .{ 6.0, 0.0, 0.0 }, // 6 units wide
        .pad1 = 0,
        .v_vec = .{ 0.0, 0.0, 6.0 }, // 6 units deep
        .pad2 = 0,
        .normal = .{ 0.0, -1.0, 0.0 }, // Pointing down
        .area = 36.0, // 6 * 6
        .color = .{ 1.0, 0.95, 0.9 }, // Warm white
        .intensity = 8.0,
    });

    // Blue accent light on the left
    try area_lights.append(.{
        .position = .{ -10.0, 2.0, -2.0 },
        .pad0 = 0,
        .u_vec = .{ 0.0, 3.0, 0.0 }, // 3 units tall
        .pad1 = 0,
        .v_vec = .{ 0.0, 0.0, 4.0 }, // 4 units deep
        .pad2 = 0,
        .normal = .{ 1.0, 0.0, 0.0 }, // Pointing right
        .area = 12.0, // 3 * 4
        .color = .{ 0.3, 0.5, 1.0 }, // Blue
        .intensity = 5.0,
    });

    // Orange rim light on the right
    try area_lights.append(.{
        .position = .{ 10.0, 1.0, 0.0 },
        .pad0 = 0,
        .u_vec = .{ 0.0, 2.0, 0.0 }, // 2 units tall
        .pad1 = 0,
        .v_vec = .{ 0.0, 0.0, 3.0 }, // 3 units deep
        .pad2 = 0,
        .normal = .{ -1.0, 0.0, 0.0 }, // Pointing left
        .area = 6.0, // 2 * 3
        .color = .{ 1.0, 0.6, 0.3 }, // Orange
        .intensity = 4.0,
    });

    std.debug.print("Area lights: {}\n", .{area_lights.items.len});

    // Upload area light buffer
    var area_light_ssbo: GLuint = 0;
    glGenBuffers(1, &area_light_ssbo);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, area_light_ssbo);
    const area_light_header_size = 16;
    const area_light_buffer_size = area_light_header_size + area_lights.items.len * @sizeOf(GPUAreaLight);
    const area_light_buffer_data = try allocator.alloc(u8, area_light_buffer_size);
    defer allocator.free(area_light_buffer_data);
    const num_area_lights: i32 = @intCast(area_lights.items.len);
    @memcpy(area_light_buffer_data[0..4], std.mem.asBytes(&num_area_lights));
    @memset(area_light_buffer_data[4..16], 0);
    if (area_lights.items.len > 0) {
        @memcpy(area_light_buffer_data[area_light_header_size..], std.mem.sliceAsBytes(area_lights.items));
    }
    glBufferData(GL_SHADER_STORAGE_BUFFER, @intCast(area_light_buffer_size), area_light_buffer_data.ptr, GL_DYNAMIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 6, area_light_ssbo);

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
    const u_normal_strength_loc = glGetUniformLocation(compute_program, "u_normal_strength");
    const u_denoise_loc = glGetUniformLocation(compute_program, "u_denoise");
    const u_fog_density_loc = glGetUniformLocation(compute_program, "u_fog_density");
    const u_fog_color_loc = glGetUniformLocation(compute_program, "u_fog_color");
    const u_film_grain_loc = glGetUniformLocation(compute_program, "u_film_grain");
    const u_bokeh_shape_loc = glGetUniformLocation(compute_program, "u_bokeh_shape");

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
        // M - Normal mapping strength (hold Shift for decrease)
        if (g_keys['M']) {
            if (g_keys[0x10]) {
                g_normal_strength = @max(0.0, g_normal_strength - 0.25);
            } else {
                g_normal_strength = @min(5.0, g_normal_strength + 0.25);
            }
            camera_moved = true; g_keys['M'] = false;
        }
        // O - Denoising strength (hold Shift for decrease)
        if (g_keys['O']) {
            if (g_keys[0x10]) {
                g_denoise_strength = @max(0.0, g_denoise_strength - 0.1);
            } else {
                g_denoise_strength = @min(2.0, g_denoise_strength + 0.1);
            }
            camera_moved = true; g_keys['O'] = false;
        }
        // P - Volumetric fog density (hold Shift for decrease)
        if (g_keys['P']) {
            if (g_keys[0x10]) {
                g_fog_density = @max(0.0, g_fog_density - 0.01);
            } else {
                g_fog_density = @min(0.5, g_fog_density + 0.01);
            }
            camera_moved = true; g_keys['P'] = false;
        }
        // G - Film grain (hold Shift for decrease)
        if (g_keys['G']) {
            if (g_keys[0x10]) {
                g_film_grain = @max(0.0, g_film_grain - 0.1);
            } else {
                g_film_grain = @min(2.0, g_film_grain + 0.1);
            }
            camera_moved = true; g_keys['G'] = false;
        }
        // K - Cycle bokeh shape (circle/hexagon/star/heart)
        if (g_keys['K']) {
            g_bokeh_shape = @mod(g_bokeh_shape + 1, 4);
            camera_moved = true; g_keys['K'] = false;
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
        glUniform1f(u_normal_strength_loc, g_normal_strength);
        glUniform1f(u_denoise_loc, g_denoise_strength);
        glUniform1f(u_fog_density_loc, g_fog_density);
        glUniform3f(u_fog_color_loc, g_fog_color[0], g_fog_color[1], g_fog_color[2]);
        glUniform1f(u_film_grain_loc, g_film_grain);
        glUniform1i(u_bokeh_shape_loc, g_bokeh_shape);

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

// setupScene moved to scene.zig
