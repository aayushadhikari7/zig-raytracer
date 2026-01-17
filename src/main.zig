const std = @import("std");
const vec3 = @import("vec3.zig");
const types = @import("types.zig");
const bvh = @import("bvh.zig");
const obj_loader = @import("obj_loader.zig");
const scene = @import("scene.zig");
const shader_module = @import("shader.zig");
const hud = @import("hud.zig");

const GPUSphere = types.GPUSphere;
const GPUTriangle = types.GPUTriangle;
const GPUBVHNode = types.GPUBVHNode;
const GPUAreaLight = types.GPUAreaLight;
const GPUMeshInstance = types.GPUMeshInstance;

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
const MAX_DEPTH: u32 = 4;  // Reduced for better FPS
const SAMPLES_PER_FRAME: u32 = 2;  // Lower = better FPS

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
const PFNGLBUFFERSUBDATAPROC = *const fn (GLenum, isize, GLsizeiptr, ?*const anyopaque) callconv(std.builtin.CallingConvention.c) void;
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
var glBufferSubData: PFNGLBUFFERSUBDATAPROC = undefined;
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
var g_camera_roll: f32 = 0.0; // Roll angle for flight mode
var g_flight_mode: bool = false; // false = FPS camera, true = flight simulator camera

// Runtime adjustable settings
var g_fov: f32 = 20.0;
var g_aperture: f32 = 0.0;
var g_focus_dist: f32 = 10.0;
var g_samples_per_frame: u32 = 1; // Use 1-4 keys to increase for quality
var g_save_screenshot: bool = false;
var g_show_help: bool = true;

// Effect controls
var g_chromatic_strength: f32 = 0.003;
var g_motion_blur_strength: f32 = 0.5;
var g_bloom_strength: f32 = 0.15;
var g_nee_enabled: bool = true;
var g_roughness_mult: f32 = 1.0;
var g_exposure: f32 = 2.0;
var g_vignette_strength: f32 = 0.15;
var g_normal_strength: f32 = 1.5; // Normal map strength
var g_displacement: f32 = 0.5; // Displacement/parallax mapping strength
var g_denoise_strength: f32 = 0.5; // Denoising strength (0 = off)
var g_fog_density: f32 = 0.0; // Volumetric fog density (0 = off)
var g_fog_color: [3]f32 = .{ 0.8, 0.85, 0.95 }; // Fog color (blueish)
var g_film_grain: f32 = 0.0; // Film grain strength (0 = off)
var g_bokeh_shape: i32 = 0; // 0=circle, 1=hexagon, 2=star, 3=heart
var g_debug_mode: i32 = 0; // 0=normal, 1=BVH heatmap, 2=normals, 3=depth
var g_dispersion: f32 = 0.0; // Glass dispersion strength (0 = off, chromatic aberration in glass)
var g_lens_flare: f32 = 0.0; // Lens flare strength (0 = off)
var g_iridescence: f32 = 0.0; // Thin-film iridescence strength
var g_anisotropy: f32 = 0.0; // Anisotropic reflection strength (brushed metal)
var g_color_temp: f32 = 0.0; // Color temperature adjustment (-1 = cool, +1 = warm)
var g_saturation: f32 = 1.0; // Saturation multiplier
var g_scanlines: f32 = 0.0; // CRT scanline effect strength
var g_tilt_shift: f32 = 0.0; // Tilt-shift miniature effect
var g_glitter: f32 = 0.0; // Glitter/sparkle material intensity
var g_heat_haze: f32 = 0.0; // Heat haze distortion
// MEGA EFFECTS BATCH 2
var g_kaleidoscope: f32 = 0.0; // Kaleidoscope segments (0=off, 3-12 = segments)
var g_pixelate: f32 = 0.0; // Pixelation amount (0=off)
var g_edge_detect: f32 = 0.0; // Edge detection / toon outline
var g_halftone: f32 = 0.0; // Halftone / comic book dots
var g_night_vision: f32 = 0.0; // Night vision green effect
var g_thermal: f32 = 0.0; // Thermal vision
var g_underwater: f32 = 0.0; // Underwater caustics and color
var g_rain_drops: f32 = 0.0; // Rain droplets on lens
var g_vhs_effect: f32 = 0.0; // VHS / old film effect
var g_anaglyph_3d: f32 = 0.0; // Red/cyan 3D anaglyph
var g_fisheye: f32 = 0.0; // Fisheye lens distortion
var g_posterize: f32 = 0.0; // Color posterization (0=off, 2-16 = levels)
var g_sepia: f32 = 0.0; // Sepia / vintage filter
var g_frosted: f32 = 0.0; // Frosted glass blur
var g_radial_blur: f32 = 0.0; // Radial / zoom blur
var g_dither: f32 = 0.0; // Dithering effect
var g_holographic: f32 = 0.0; // Holographic rainbow material
var g_ascii_mode: f32 = 0.0; // ASCII art rendering
var g_show_hud: bool = true; // TAB to toggle

// Menu item IDs
const IDM_FILE_LOAD_OBJ: c_uint = 101;
const IDM_FILE_SCREENSHOT: c_uint = 102;
const IDM_FILE_EXIT: c_uint = 103;
const IDM_VIEW_HUD: c_uint = 201;
const IDM_VIEW_NORMAL: c_uint = 202;
const IDM_VIEW_HEATMAP: c_uint = 203;
const IDM_VIEW_NORMALS: c_uint = 204;
const IDM_VIEW_DEPTH: c_uint = 205;
const IDM_VIEW_FLIGHT: c_uint = 206;
const IDM_SCENE_ADD_SPHERE: c_uint = 301;
const IDM_SCENE_ADD_LIGHT: c_uint = 302;
const IDM_SCENE_ADD_GLASS: c_uint = 303;
const IDM_SCENE_ADD_METAL: c_uint = 304;
const IDM_SCENE_REMOVE_LAST: c_uint = 305;
const IDM_SCENE_RESET: c_uint = 306;
const IDM_HELP_CONTROLS: c_uint = 401;
const IDM_HELP_ABOUT: c_uint = 402;

// Menu flags
const MF_STRING: c_uint = 0x0000;
const MF_POPUP: c_uint = 0x0010;
const MF_SEPARATOR: c_uint = 0x0800;

// Pending actions from menu
var g_menu_action: c_uint = 0;
var g_scene_dirty: bool = false; // Flag to rebuild scene when spheres change

fn createMenuBar(hwnd: win32.HWND) void {
    const hMenu = win32.CreateMenu();
    if (hMenu == null) return;

    // File menu
    const hFileMenu = win32.CreatePopupMenu();
    _ = win32.AppendMenuA(hFileMenu, MF_STRING, IDM_FILE_LOAD_OBJ, "Load OBJ...");
    _ = win32.AppendMenuA(hFileMenu, MF_STRING, IDM_FILE_SCREENSHOT, "Save Screenshot\tF12");
    _ = win32.AppendMenuA(hFileMenu, MF_SEPARATOR, 0, null);
    _ = win32.AppendMenuA(hFileMenu, MF_STRING, IDM_FILE_EXIT, "Exit\tAlt+F4");
    _ = win32.AppendMenuA(hMenu, MF_POPUP, @intFromPtr(hFileMenu), "File");

    // View menu
    const hViewMenu = win32.CreatePopupMenu();
    _ = win32.AppendMenuA(hViewMenu, MF_STRING, IDM_VIEW_HUD, "Toggle HUD\tTAB");
    _ = win32.AppendMenuA(hViewMenu, MF_STRING, IDM_VIEW_FLIGHT, "Toggle Flight Mode\tP");
    _ = win32.AppendMenuA(hViewMenu, MF_SEPARATOR, 0, null);
    _ = win32.AppendMenuA(hViewMenu, MF_STRING, IDM_VIEW_NORMAL, "Normal View\t5");
    _ = win32.AppendMenuA(hViewMenu, MF_STRING, IDM_VIEW_HEATMAP, "BVH Heatmap\t6");
    _ = win32.AppendMenuA(hViewMenu, MF_STRING, IDM_VIEW_NORMALS, "Normals\t7");
    _ = win32.AppendMenuA(hViewMenu, MF_STRING, IDM_VIEW_DEPTH, "Depth\t8");
    _ = win32.AppendMenuA(hMenu, MF_POPUP, @intFromPtr(hViewMenu), "View");

    // Scene menu
    const hSceneMenu = win32.CreatePopupMenu();
    _ = win32.AppendMenuA(hSceneMenu, MF_STRING, IDM_SCENE_ADD_SPHERE, "Add Diffuse Sphere");
    _ = win32.AppendMenuA(hSceneMenu, MF_STRING, IDM_SCENE_ADD_METAL, "Add Metal Sphere");
    _ = win32.AppendMenuA(hSceneMenu, MF_STRING, IDM_SCENE_ADD_GLASS, "Add Glass Sphere");
    _ = win32.AppendMenuA(hSceneMenu, MF_STRING, IDM_SCENE_ADD_LIGHT, "Add Light");
    _ = win32.AppendMenuA(hSceneMenu, MF_SEPARATOR, 0, null);
    _ = win32.AppendMenuA(hSceneMenu, MF_STRING, IDM_SCENE_REMOVE_LAST, "Remove Last Sphere");
    _ = win32.AppendMenuA(hSceneMenu, MF_STRING, IDM_SCENE_RESET, "Reset Scene\tR");
    _ = win32.AppendMenuA(hMenu, MF_POPUP, @intFromPtr(hSceneMenu), "Scene");

    // Help menu
    const hHelpMenu = win32.CreatePopupMenu();
    _ = win32.AppendMenuA(hHelpMenu, MF_STRING, IDM_HELP_CONTROLS, "Controls...");
    _ = win32.AppendMenuA(hHelpMenu, MF_STRING, IDM_HELP_ABOUT, "About...");
    _ = win32.AppendMenuA(hMenu, MF_POPUP, @intFromPtr(hHelpMenu), "Help");

    _ = win32.SetMenu(hwnd, hMenu);
}

fn windowProc(hwnd: win32.HWND, msg: c_uint, wparam: win32.WPARAM, lparam: win32.LPARAM) callconv(std.builtin.CallingConvention.c) win32.LRESULT {
    const WM_COMMAND: c_uint = 0x0111;
    switch (msg) {
        win32.WM_DESTROY, win32.WM_CLOSE => {
            g_running = false;
            return 0;
        },
        WM_COMMAND => {
            const cmd: c_uint = @truncate(wparam & 0xFFFF);
            switch (cmd) {
                IDM_FILE_EXIT => g_running = false,
                IDM_FILE_SCREENSHOT => g_save_screenshot = true,
                IDM_VIEW_HUD => g_show_hud = !g_show_hud,
                IDM_VIEW_NORMAL => g_debug_mode = 0,
                IDM_VIEW_HEATMAP => g_debug_mode = 1,
                IDM_VIEW_NORMALS => g_debug_mode = 2,
                IDM_VIEW_DEPTH => g_debug_mode = 3,
                IDM_VIEW_FLIGHT => g_flight_mode = !g_flight_mode,
                IDM_HELP_ABOUT => {
                    _ = win32.MessageBoxA(hwnd, "Zig GPU Raytracer v1.0\n\nFeatures:\n- Path tracing with BVH\n- PBR materials\n- OBJ loading\n- Flight camera mode\n- 40+ post-processing effects\n\nPress TAB for controls.", "About Raytracer", 0x40);
                },
                IDM_HELP_CONTROLS => {
                    _ = win32.MessageBoxA(hwnd, "CONTROLS:\n\nWASD - Move camera\nSpace/Ctrl - Up/Down\nRight-click - Toggle mouse look\nP - Toggle flight mode\nQ/E - Roll (flight mode)\nR - Reset everything\n\n5-8 - Debug modes\n1-4 - Quality presets\nTAB - Toggle HUD\nF12 - Screenshot\n\nShift+Key - Decrease effect", "Controls", 0x40);
                },
                else => g_menu_action = cmd, // Handle in main loop
            }
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
    glBufferSubData = load(PFNGLBUFFERSUBDATAPROC, "glBufferSubData") orelse return false;
    glBindBufferBase = load(PFNGLBINDBUFFERBASEPROC, "glBindBufferBase") orelse return false;
    glActiveTexture = load(PFNGLACTIVETEXTUREPROC, "glActiveTexture") orelse return false;
    return true;
}


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

    // Create the menu bar
    createMenuBar(hwnd);

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

    // Pre-allocate buffers for max spheres (allows dynamic scene editing)
    const MAX_SPHERES: usize = 200;
    const MAX_BVH_NODES: usize = MAX_SPHERES * 2; // BVH has at most 2n-1 nodes

    // Upload sphere buffer
    var sphere_ssbo: GLuint = 0;
    glGenBuffers(1, &sphere_ssbo);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, sphere_ssbo);
    const sphere_header_size = 16;
    const sphere_buffer_size = sphere_header_size + MAX_SPHERES * @sizeOf(GPUSphere);
    glBufferData(GL_SHADER_STORAGE_BUFFER, @intCast(sphere_buffer_size), null, GL_DYNAMIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 2, sphere_ssbo);

    // Upload BVH buffer
    var bvh_ssbo: GLuint = 0;
    glGenBuffers(1, &bvh_ssbo);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, bvh_ssbo);
    const bvh_header_size = 16;
    const bvh_buffer_size = bvh_header_size + MAX_BVH_NODES * @sizeOf(GPUBVHNode);
    glBufferData(GL_SHADER_STORAGE_BUFFER, @intCast(bvh_buffer_size), null, GL_DYNAMIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 3, bvh_ssbo);

    // Helper to upload scene data to GPU
    const uploadScene = struct {
        fn call(
            alloc: std.mem.Allocator,
            sphere_list: *std.ArrayList(GPUSphere),
            bvh_list: *std.ArrayList(GPUBVHNode),
            s_ssbo: GLuint,
            b_ssbo: GLuint,
        ) !void {
            // Rebuild BVH
            bvh_list.clearRetainingCapacity();
            var idx = try alloc.alloc(u32, sphere_list.items.len);
            defer alloc.free(idx);
            for (0..sphere_list.items.len) |i| idx[i] = @intCast(i);
            _ = try bvh.buildBVH(alloc, sphere_list.items, idx, bvh_list);

            // Upload spheres
            glBindBuffer(GL_SHADER_STORAGE_BUFFER, s_ssbo);
            const s_size = sphere_header_size + sphere_list.items.len * @sizeOf(GPUSphere);
            const s_data = try alloc.alloc(u8, s_size);
            defer alloc.free(s_data);
            const num_s: i32 = @intCast(sphere_list.items.len);
            @memcpy(s_data[0..4], std.mem.asBytes(&num_s));
            @memset(s_data[4..16], 0);
            @memcpy(s_data[sphere_header_size..], std.mem.sliceAsBytes(sphere_list.items));
            glBufferSubData(GL_SHADER_STORAGE_BUFFER, 0, @intCast(s_size), s_data.ptr);

            // Upload BVH
            glBindBuffer(GL_SHADER_STORAGE_BUFFER, b_ssbo);
            const b_size = bvh_header_size + bvh_list.items.len * @sizeOf(GPUBVHNode);
            const b_data = try alloc.alloc(u8, b_size);
            defer alloc.free(b_data);
            const num_b: i32 = @intCast(bvh_list.items.len);
            @memcpy(b_data[0..4], std.mem.asBytes(&num_b));
            @memset(b_data[4..16], 0);
            @memcpy(b_data[bvh_header_size..], std.mem.sliceAsBytes(bvh_list.items));
            glBufferSubData(GL_SHADER_STORAGE_BUFFER, 0, @intCast(b_size), b_data.ptr);

            std.debug.print("Scene updated: {} spheres, {} BVH nodes\n", .{ sphere_list.items.len, bvh_list.items.len });
        }
    }.call;

    // Initial upload
    try uploadScene(allocator, &spheres, &bvh_nodes, sphere_ssbo, bvh_ssbo);

    // Load triangle meshes - try OBJ files first, fallback to procedural
    var triangles = std.ArrayList(GPUTriangle){};
    defer triangles.deinit(allocator);

    // Try loading OBJ files from models folder
    // Model 1: Golden torus (center)
    if (obj_loader.loadObj(allocator, "models/torus.obj", .{
        .scale = 0.8,
        .offset = Vec3.init(0.0, 1.2, -5.0),
        .albedo = .{ 1.0, 0.84, 0.0 }, // Gold
        .mat_type = 1, // Metal
    })) |mesh| {
        defer @constCast(&mesh).deinit(allocator);
        try triangles.appendSlice(allocator, mesh.triangles.items);
        std.debug.print("Loaded torus.obj\n", .{});
    } else |_| {}

    // Model 2: Glass diamond (left)
    if (obj_loader.loadObj(allocator, "models/diamond.obj", .{
        .scale = 0.6,
        .offset = Vec3.init(-2.5, 1.0, -4.0),
        .albedo = .{ 0.95, 0.95, 1.0 }, // Slight blue tint
        .mat_type = 2, // Glass
    })) |mesh| {
        defer @constCast(&mesh).deinit(allocator);
        try triangles.appendSlice(allocator, mesh.triangles.items);
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
        defer @constCast(&mesh).deinit(allocator);
        try triangles.appendSlice(allocator, mesh.triangles.items);
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
        defer @constCast(&mesh).deinit(allocator);
        try triangles.appendSlice(allocator, mesh.triangles.items);
        std.debug.print("Loaded cube.obj\n", .{});
    } else |_| {}

    // Fallback: if no models loaded, create procedural shapes
    if (triangles.items.len == 0) {
        std.debug.print("No OBJ files found, creating procedural meshes\n", .{});

        // Gold icosphere (center)
        try obj_loader.createIcosphere(allocator, &triangles, Vec3.init(0.0, 1.5, -5.0), 1.0, 2, .{
            .albedo = .{ 1.0, 0.84, 0.0 },
            .mat_type = 1,
            .emissive = 0.0,
        });

        // Glass icosphere (left)
        try obj_loader.createIcosphere(allocator, &triangles, Vec3.init(-2.5, 1.0, -4.0), 0.8, 2, .{
            .albedo = .{ 1.0, 1.0, 1.0 },
            .mat_type = 2,
            .emissive = 0.0,
        });

        // Red diffuse icosphere (right)
        try obj_loader.createIcosphere(allocator, &triangles, Vec3.init(2.5, 1.0, -4.0), 0.8, 2, .{
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
    var tri_bvh_nodes = std.ArrayList(GPUBVHNode){};
    defer tri_bvh_nodes.deinit(allocator);

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
    var area_lights = std.ArrayList(GPUAreaLight){};
    defer area_lights.deinit(allocator);

    // Large overhead rectangular light (studio lighting style)
    try area_lights.append(allocator, .{
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
    try area_lights.append(allocator, .{
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
    try area_lights.append(allocator, .{
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

    // Build per-mesh BVH for instanced rendering (binding 12)
    // This allows O(log n) triangle intersection instead of O(n)
    var mesh_bvh_nodes = std.ArrayList(GPUBVHNode){};
    defer mesh_bvh_nodes.deinit(allocator);
    var mesh_bvh_root: i32 = -1; // -1 means no BVH, fallback to linear

    if (triangles.items.len > 0) {
        // Build BVH with RELATIVE indices (0 to N-1)
        var mesh_indices = try allocator.alloc(u32, triangles.items.len);
        defer allocator.free(mesh_indices);
        for (0..triangles.items.len) |i| {
            mesh_indices[i] = @intCast(i);
        }
        mesh_bvh_root = @intCast(try bvh.buildTriangleBVH(allocator, triangles.items, mesh_indices, &mesh_bvh_nodes));
        std.debug.print("Mesh BVH: {} nodes, root={}\n", .{ mesh_bvh_nodes.items.len, mesh_bvh_root });
    }

    // Upload mesh BVH buffer (binding 12)
    var mesh_bvh_ssbo: GLuint = 0;
    glGenBuffers(1, &mesh_bvh_ssbo);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, mesh_bvh_ssbo);
    if (mesh_bvh_nodes.items.len > 0) {
        glBufferData(GL_SHADER_STORAGE_BUFFER, @intCast(mesh_bvh_nodes.items.len * @sizeOf(GPUBVHNode)), mesh_bvh_nodes.items.ptr, GL_DYNAMIC_DRAW);
    } else {
        glBufferData(GL_SHADER_STORAGE_BUFFER, 16, null, GL_DYNAMIC_DRAW);
    }
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 12, mesh_bvh_ssbo);

    // Create mesh instances (example: multiple instances of loaded meshes)
    var instances = std.ArrayList(GPUMeshInstance){};
    defer instances.deinit(allocator);

    // Only create instances if we have triangles
    if (triangles.items.len > 0) {
        // For demo, create instances of ALL loaded triangles as a single mesh
        // In a real scenario, you'd track individual mesh ranges
        const mesh_start: i32 = 0;
        const mesh_end: i32 = @intCast(triangles.items.len);

        // Create a ring of instances around the scene
        const num_copies: i32 = 6;
        var i: i32 = 0;
        while (i < num_copies) : (i += 1) {
            const angle = @as(f32, @floatFromInt(i)) * 6.28318 / @as(f32, @floatFromInt(num_copies));
            const radius: f32 = 12.0;
            const x = @cos(angle) * radius;
            const z = @sin(angle) * radius - 5.0; // Offset to match scene center

            // Create transform: translate, then rotate to face center
            const trans = types.translationMatrix(x, 0, z);
            const rot = types.rotationYMatrix(angle + 3.14159);
            const transform_mat = types.multiplyMatrix(trans, rot);

            // Pass mesh_bvh_root so instance uses BVH traversal
            try instances.append(allocator, types.createInstance(transform_mat, mesh_start, mesh_end, mesh_bvh_root));
        }
    }

    std.debug.print("Mesh instances: {}\n", .{instances.items.len});

    // Upload instance buffer (binding 7)
    var instance_ssbo: GLuint = 0;
    glGenBuffers(1, &instance_ssbo);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, instance_ssbo);
    const instance_header_size = 16;
    const instance_buffer_size = instance_header_size + instances.items.len * @sizeOf(GPUMeshInstance);
    const instance_buffer_data = try allocator.alloc(u8, instance_buffer_size);
    defer allocator.free(instance_buffer_data);
    const num_instances: i32 = @intCast(instances.items.len);
    @memcpy(instance_buffer_data[0..4], std.mem.asBytes(&num_instances));
    @memset(instance_buffer_data[4..16], 0);
    if (instances.items.len > 0) {
        @memcpy(instance_buffer_data[instance_header_size..], std.mem.sliceAsBytes(instances.items));
    }
    glBufferData(GL_SHADER_STORAGE_BUFFER, @intCast(instance_buffer_size), instance_buffer_data.ptr, GL_DYNAMIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 7, instance_ssbo);

    // Empty instance BVH for now (binding 8) - linear search when few instances
    var instance_bvh_ssbo: GLuint = 0;
    glGenBuffers(1, &instance_bvh_ssbo);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, instance_bvh_ssbo);
    glBufferData(GL_SHADER_STORAGE_BUFFER, 16, null, GL_DYNAMIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 8, instance_bvh_ssbo);

    // Create CSG primitives (binding 9)
    var csg_primitives = std.ArrayList(types.GPUCSGPrimitive){};
    defer csg_primitives.deinit(allocator);

    // Create CSG objects (binding 10)
    var csg_objects = std.ArrayList(types.GPUCSGObject){};
    defer csg_objects.deinit(allocator);

    // Demo CSG: Sphere with box subtracted (creates rounded cutout)
    // Primitive 0: Large sphere
    try csg_primitives.append(allocator, .{
        .center = .{ -3.0, 1.5, -3.0 },
        .prim_type = types.CSG_PRIM_SPHERE,
        .size = .{ 1.0, 0, 0 },
        .pad0 = 0,
        .rotation = .{ 0, 0, 0 },
        .pad1 = 0,
    });
    // Primitive 1: Smaller box for subtraction
    try csg_primitives.append(allocator, .{
        .center = .{ -3.0, 1.8, -2.5 },
        .prim_type = types.CSG_PRIM_BOX,
        .size = .{ 0.5, 0.5, 0.5 },
        .pad0 = 0,
        .rotation = .{ 0.3, 0.5, 0 },
        .pad1 = 0,
    });

    // CSG object 0: Sphere - Box (carved sphere)
    try csg_objects.append(allocator, .{
        .prim_a = 0,
        .prim_b = 1,
        .operation = types.CSG_OP_SUBTRACT,
        .smooth_k = 0.1,
        .albedo = .{ 0.9, 0.2, 0.3 }, // Red
        .mat_type = 0, // Diffuse
        .fuzz = 0,
        .ior = 0,
        .emissive = 0,
        .pad = 0,
    });

    // Demo CSG 2: Smooth union of two spheres (organic blob)
    // Primitive 2: First blob sphere
    try csg_primitives.append(allocator, .{
        .center = .{ 3.0, 0.8, -3.0 },
        .prim_type = types.CSG_PRIM_SPHERE,
        .size = .{ 0.7, 0, 0 },
        .pad0 = 0,
        .rotation = .{ 0, 0, 0 },
        .pad1 = 0,
    });
    // Primitive 3: Second blob sphere
    try csg_primitives.append(allocator, .{
        .center = .{ 3.5, 1.2, -2.8 },
        .prim_type = types.CSG_PRIM_SPHERE,
        .size = .{ 0.5, 0, 0 },
        .pad0 = 0,
        .rotation = .{ 0, 0, 0 },
        .pad1 = 0,
    });

    // CSG object 1: Smooth union blob
    try csg_objects.append(allocator, .{
        .prim_a = 2,
        .prim_b = 3,
        .operation = types.CSG_OP_SMOOTH_UNION,
        .smooth_k = 0.3,
        .albedo = .{ 0.2, 0.8, 0.4 }, // Green
        .mat_type = 1, // Metal
        .fuzz = 0.1,
        .ior = 0,
        .emissive = 0,
        .pad = 0,
    });

    // Demo CSG 3: Box intersected with sphere (rounded cube)
    // Primitive 4: Box
    try csg_primitives.append(allocator, .{
        .center = .{ 0.0, 0.8, -6.0 },
        .prim_type = types.CSG_PRIM_BOX,
        .size = .{ 0.7, 0.7, 0.7 },
        .pad0 = 0,
        .rotation = .{ 0.2, 0.4, 0 },
        .pad1 = 0,
    });
    // Primitive 5: Slightly larger sphere
    try csg_primitives.append(allocator, .{
        .center = .{ 0.0, 0.8, -6.0 },
        .prim_type = types.CSG_PRIM_SPHERE,
        .size = .{ 0.9, 0, 0 },
        .pad0 = 0,
        .rotation = .{ 0, 0, 0 },
        .pad1 = 0,
    });

    // CSG object 2: Box intersect Sphere (rounded cube)
    try csg_objects.append(allocator, .{
        .prim_a = 4,
        .prim_b = 5,
        .operation = types.CSG_OP_INTERSECT,
        .smooth_k = 0,
        .albedo = .{ 0.95, 0.95, 1.0 }, // Glass-like
        .mat_type = 2, // Glass
        .fuzz = 0,
        .ior = 1.5,
        .emissive = 0,
        .pad = 0,
    });

    std.debug.print("CSG primitives: {}, CSG objects: {}\n", .{ csg_primitives.items.len, csg_objects.items.len });

    // Upload CSG primitive buffer (binding 9)
    var csg_prim_ssbo: GLuint = 0;
    glGenBuffers(1, &csg_prim_ssbo);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, csg_prim_ssbo);
    const csg_prim_header_size = 16;
    const csg_prim_buffer_size = csg_prim_header_size + csg_primitives.items.len * @sizeOf(types.GPUCSGPrimitive);
    const csg_prim_buffer_data = try allocator.alloc(u8, csg_prim_buffer_size);
    defer allocator.free(csg_prim_buffer_data);
    const num_csg_prims: i32 = @intCast(csg_primitives.items.len);
    @memcpy(csg_prim_buffer_data[0..4], std.mem.asBytes(&num_csg_prims));
    @memset(csg_prim_buffer_data[4..16], 0);
    if (csg_primitives.items.len > 0) {
        @memcpy(csg_prim_buffer_data[csg_prim_header_size..], std.mem.sliceAsBytes(csg_primitives.items));
    }
    glBufferData(GL_SHADER_STORAGE_BUFFER, @intCast(csg_prim_buffer_size), csg_prim_buffer_data.ptr, GL_DYNAMIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 9, csg_prim_ssbo);

    // Upload CSG object buffer (binding 10)
    var csg_obj_ssbo: GLuint = 0;
    glGenBuffers(1, &csg_obj_ssbo);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, csg_obj_ssbo);
    const csg_obj_header_size = 16;
    const csg_obj_buffer_size = csg_obj_header_size + csg_objects.items.len * @sizeOf(types.GPUCSGObject);
    const csg_obj_buffer_data = try allocator.alloc(u8, csg_obj_buffer_size);
    defer allocator.free(csg_obj_buffer_data);
    const num_csg_objs: i32 = @intCast(csg_objects.items.len);
    @memcpy(csg_obj_buffer_data[0..4], std.mem.asBytes(&num_csg_objs));
    @memset(csg_obj_buffer_data[4..16], 0);
    if (csg_objects.items.len > 0) {
        @memcpy(csg_obj_buffer_data[csg_obj_header_size..], std.mem.sliceAsBytes(csg_objects.items));
    }
    glBufferData(GL_SHADER_STORAGE_BUFFER, @intCast(csg_obj_buffer_size), csg_obj_buffer_data.ptr, GL_DYNAMIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 10, csg_obj_ssbo);

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
    const u_displacement_loc = glGetUniformLocation(compute_program, "u_displacement");
    const u_denoise_loc = glGetUniformLocation(compute_program, "u_denoise");
    const u_fog_density_loc = glGetUniformLocation(compute_program, "u_fog_density");
    const u_fog_color_loc = glGetUniformLocation(compute_program, "u_fog_color");
    const u_film_grain_loc = glGetUniformLocation(compute_program, "u_film_grain");
    const u_dispersion_loc = glGetUniformLocation(compute_program, "u_dispersion");
    const u_lens_flare_loc = glGetUniformLocation(compute_program, "u_lens_flare");
    const u_iridescence_loc = glGetUniformLocation(compute_program, "u_iridescence");
    const u_anisotropy_loc = glGetUniformLocation(compute_program, "u_anisotropy");
    const u_color_temp_loc = glGetUniformLocation(compute_program, "u_color_temp");
    const u_saturation_loc = glGetUniformLocation(compute_program, "u_saturation");
    const u_scanlines_loc = glGetUniformLocation(compute_program, "u_scanlines");
    const u_tilt_shift_loc = glGetUniformLocation(compute_program, "u_tilt_shift");
    const u_glitter_loc = glGetUniformLocation(compute_program, "u_glitter");
    const u_heat_haze_loc = glGetUniformLocation(compute_program, "u_heat_haze");
    // MEGA EFFECTS BATCH 2 uniform locations
    const u_kaleidoscope_loc = glGetUniformLocation(compute_program, "u_kaleidoscope");
    const u_pixelate_loc = glGetUniformLocation(compute_program, "u_pixelate");
    const u_edge_detect_loc = glGetUniformLocation(compute_program, "u_edge_detect");
    const u_halftone_loc = glGetUniformLocation(compute_program, "u_halftone");
    const u_night_vision_loc = glGetUniformLocation(compute_program, "u_night_vision");
    const u_thermal_loc = glGetUniformLocation(compute_program, "u_thermal");
    const u_underwater_loc = glGetUniformLocation(compute_program, "u_underwater");
    const u_rain_drops_loc = glGetUniformLocation(compute_program, "u_rain_drops");
    const u_vhs_effect_loc = glGetUniformLocation(compute_program, "u_vhs_effect");
    const u_anaglyph_3d_loc = glGetUniformLocation(compute_program, "u_anaglyph_3d");
    const u_fisheye_loc = glGetUniformLocation(compute_program, "u_fisheye");
    const u_posterize_loc = glGetUniformLocation(compute_program, "u_posterize");
    const u_sepia_loc = glGetUniformLocation(compute_program, "u_sepia");
    const u_frosted_loc = glGetUniformLocation(compute_program, "u_frosted");
    const u_radial_blur_loc = glGetUniformLocation(compute_program, "u_radial_blur");
    const u_dither_loc = glGetUniformLocation(compute_program, "u_dither");
    const u_holographic_loc = glGetUniformLocation(compute_program, "u_holographic");
    const u_ascii_mode_loc = glGetUniformLocation(compute_program, "u_ascii_mode");
    const u_bokeh_shape_loc = glGetUniformLocation(compute_program, "u_bokeh_shape");
    const u_debug_mode_loc = glGetUniformLocation(compute_program, "u_debug_mode");
    const u_instance_bvh_root_loc = glGetUniformLocation(compute_program, "u_instance_bvh_root");

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

        // Handle menu actions that modify the scene
        if (g_menu_action != 0) {
            const action = g_menu_action;
            g_menu_action = 0;

            switch (action) {
                IDM_SCENE_ADD_SPHERE => {
                    if (spheres.items.len < MAX_SPHERES) {
                        const pos = scene.getNextSpawnPosition();
                        spheres.append(allocator, scene.createDiffuseSphere(pos)) catch {};
                        g_scene_dirty = true;
                    }
                },
                IDM_SCENE_ADD_METAL => {
                    if (spheres.items.len < MAX_SPHERES) {
                        const pos = scene.getNextSpawnPosition();
                        spheres.append(allocator, scene.createMetalSphere(pos)) catch {};
                        g_scene_dirty = true;
                    }
                },
                IDM_SCENE_ADD_GLASS => {
                    if (spheres.items.len < MAX_SPHERES) {
                        const pos = scene.getNextSpawnPosition();
                        spheres.append(allocator, scene.createGlassSphere(pos)) catch {};
                        g_scene_dirty = true;
                    }
                },
                IDM_SCENE_ADD_LIGHT => {
                    if (spheres.items.len < MAX_SPHERES) {
                        const pos = scene.getNextSpawnPosition();
                        spheres.append(allocator, scene.createLightSphere(pos)) catch {};
                        g_scene_dirty = true;
                    }
                },
                IDM_SCENE_REMOVE_LAST => {
                    // Don't remove the ground plane (index 0)
                    if (spheres.items.len > 1) {
                        _ = spheres.pop();
                        g_scene_dirty = true;
                    }
                },
                IDM_SCENE_RESET => {
                    spheres.clearRetainingCapacity();
                    scene.resetSpawnPosition();
                    scene.setupScene(allocator, &spheres) catch {};
                    g_scene_dirty = true;
                },
                else => {},
            }
        }

        // Rebuild and re-upload scene if modified
        if (g_scene_dirty) {
            g_scene_dirty = false;
            uploadScene(allocator, &spheres, &bvh_nodes, sphere_ssbo, bvh_ssbo) catch {};
            total_frames = 0; // Reset accumulation
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
        const cos_roll = @cos(g_camera_roll);
        const sin_roll = @sin(g_camera_roll);

        // Base forward and right vectors (before roll)
        const base_forward = Vec3.init(cos_pitch * cos_yaw, sin_pitch, cos_pitch * sin_yaw).normalize();
        const base_right = Vec3.init(-sin_yaw, 0, cos_yaw).normalize();
        const base_up = base_right.cross(base_forward).normalize();

        // Apply roll rotation to right and up vectors
        const forward = base_forward;
        const right = base_right.scale(cos_roll).add(base_up.scale(sin_roll)).normalize();
        const up = base_up.scale(cos_roll).sub(base_right.scale(sin_roll)).normalize();

        const move_speed: f32 = 8.0 * delta_time;

        // Q/E - Roll control (only in flight mode)
        if (g_flight_mode) {
            if (g_keys['Q']) { g_camera_roll -= 2.0 * delta_time; camera_moved = true; }
            if (g_keys['E']) { g_camera_roll += 2.0 * delta_time; camera_moved = true; }
        }

        // Movement differs based on camera mode
        if (g_flight_mode) {
            // Flight simulator mode: W/S move in the direction you're looking
            if (g_keys['W']) { g_camera_pos = g_camera_pos.add(forward.scale(move_speed)); camera_moved = true; }
            if (g_keys['S']) { g_camera_pos = g_camera_pos.add(forward.scale(-move_speed)); camera_moved = true; }
            if (g_keys['A']) { g_camera_pos = g_camera_pos.add(right.scale(-move_speed)); camera_moved = true; }
            if (g_keys['D']) { g_camera_pos = g_camera_pos.add(right.scale(move_speed)); camera_moved = true; }
            // Space/Ctrl move along local up vector (strafe up/down relative to camera)
            if (g_keys[' ']) { g_camera_pos = g_camera_pos.add(up.scale(move_speed)); camera_moved = true; }
            if (g_keys[win32.VK_CONTROL]) { g_camera_pos = g_camera_pos.add(up.scale(-move_speed)); camera_moved = true; }
        } else {
            // FPS mode: W/S move forward on XZ plane, Space/Ctrl move on Y axis
            if (g_keys['W']) { g_camera_pos = g_camera_pos.add(forward.scale(move_speed)); camera_moved = true; }
            if (g_keys['S']) { g_camera_pos = g_camera_pos.add(forward.scale(-move_speed)); camera_moved = true; }
            if (g_keys['A']) { g_camera_pos = g_camera_pos.add(right.scale(-move_speed)); camera_moved = true; }
            if (g_keys['D']) { g_camera_pos = g_camera_pos.add(right.scale(move_speed)); camera_moved = true; }
            if (g_keys[' ']) { g_camera_pos.y += move_speed; camera_moved = true; }
            if (g_keys[win32.VK_CONTROL]) { g_camera_pos.y -= move_speed; camera_moved = true; }
        }
        if (g_keys['R']) {
            // Reset camera
            g_camera_pos = Vec3.init(13, 2, 3);
            g_camera_yaw = std.math.atan2(@as(f32, -3.0), @as(f32, -13.0));
            g_camera_pitch = -0.15;
            g_camera_roll = 0.0; // Reset roll
            g_flight_mode = false; // Reset to FPS mode
            g_debug_mode = 0; // Reset to normal rendering
            // Reset all effects to defaults
            g_chromatic_strength = 0.0;
            g_motion_blur_strength = 0.0;
            g_bloom_strength = 0.0;
            g_nee_enabled = true;
            g_roughness_mult = 1.0;
            g_exposure = 1.0;
            g_vignette_strength = 0.3;
            g_normal_strength = 0.0;
            g_displacement = 0.0;
            g_denoise_strength = 0.0;
            g_fog_density = 0.0;
            g_film_grain = 0.0;
            g_dispersion = 0.0;
            g_lens_flare = 0.0;
            g_iridescence = 0.0;
            g_anisotropy = 0.0;
            g_color_temp = 0.0;
            g_saturation = 1.0;
            g_scanlines = 0.0;
            g_tilt_shift = 0.0;
            g_glitter = 0.0;
            g_heat_haze = 0.0;
            g_kaleidoscope = 0.0;
            g_pixelate = 0.0;
            g_edge_detect = 0.0;
            g_halftone = 0.0;
            g_night_vision = 0.0;
            g_thermal = 0.0;
            g_underwater = 0.0;
            g_rain_drops = 0.0;
            g_vhs_effect = 0.0;
            g_anaglyph_3d = 0.0;
            g_fisheye = 0.0;
            g_posterize = 0.0;
            g_sepia = 0.0;
            g_frosted = 0.0;
            g_radial_blur = 0.0;
            g_dither = 0.0;
            g_holographic = 0.0;
            g_ascii_mode = 0.0;
            g_fov = 20.0;
            g_aperture = 0.0;
            g_focus_dist = 10.0;
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

        // P - Toggle flight mode (pilot mode with roll control)
        if (g_keys['P']) {
            g_flight_mode = !g_flight_mode;
            if (!g_flight_mode) g_camera_roll = 0.0; // Reset roll when exiting flight mode
            camera_moved = true;
            g_keys['P'] = false;
        }

        // 5-8 - Debug visualization modes
        if (g_keys['5']) { g_debug_mode = 0; camera_moved = true; g_keys['5'] = false; } // Normal
        if (g_keys['6']) { g_debug_mode = 1; camera_moved = true; g_keys['6'] = false; } // BVH Heatmap
        if (g_keys['7']) { g_debug_mode = 2; camera_moved = true; g_keys['7'] = false; } // Normals
        if (g_keys['8']) { g_debug_mode = 3; camera_moved = true; g_keys['8'] = false; } // Depth

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
        // J - Displacement/parallax mapping strength (hold Shift for decrease)
        if (g_keys['J']) {
            if (g_keys[0x10]) {
                g_displacement = @max(0.0, g_displacement - 0.1);
            } else {
                g_displacement = @min(3.0, g_displacement + 0.1);
            }
            camera_moved = true; g_keys['J'] = false;
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
        // Y - Glass dispersion (hold Shift for decrease)
        if (g_keys['Y']) {
            if (g_keys[0x10]) {
                g_dispersion = @max(0.0, g_dispersion - 0.1);
            } else {
                g_dispersion = @min(2.0, g_dispersion + 0.1);
            }
            camera_moved = true; g_keys['Y'] = false;
        }
        // L - Lens flare (hold Shift for decrease)
        if (g_keys['L']) {
            if (g_keys[0x10]) {
                g_lens_flare = @max(0.0, g_lens_flare - 0.1);
            } else {
                g_lens_flare = @min(2.0, g_lens_flare + 0.1);
            }
            camera_moved = true; g_keys['L'] = false;
        }
        // 5 - Iridescence / thin-film interference (hold Shift for decrease)
        if (g_keys['5']) {
            if (g_keys[0x10]) {
                g_iridescence = @max(0.0, g_iridescence - 0.1);
            } else {
                g_iridescence = @min(2.0, g_iridescence + 0.1);
            }
            camera_moved = true; g_keys['5'] = false;
        }
        // 6 - Anisotropic reflections / brushed metal (hold Shift for decrease)
        if (g_keys['6']) {
            if (g_keys[0x10]) {
                g_anisotropy = @max(0.0, g_anisotropy - 0.1);
            } else {
                g_anisotropy = @min(1.0, g_anisotropy + 0.1);
            }
            camera_moved = true; g_keys['6'] = false;
        }
        // 7 - Color temperature (-1 cool to +1 warm)
        if (g_keys['7']) {
            if (g_keys[0x10]) {
                g_color_temp = @max(-1.0, g_color_temp - 0.1);
            } else {
                g_color_temp = @min(1.0, g_color_temp + 0.1);
            }
            camera_moved = true; g_keys['7'] = false;
        }
        // 8 - Saturation
        if (g_keys['8']) {
            if (g_keys[0x10]) {
                g_saturation = @max(0.0, g_saturation - 0.1);
            } else {
                g_saturation = @min(2.0, g_saturation + 0.1);
            }
            camera_moved = true; g_keys['8'] = false;
        }
        // 9 - CRT scanlines
        if (g_keys['9']) {
            if (g_keys[0x10]) {
                g_scanlines = @max(0.0, g_scanlines - 0.1);
            } else {
                g_scanlines = @min(1.0, g_scanlines + 0.1);
            }
            camera_moved = true; g_keys['9'] = false;
        }
        // 0 - Tilt-shift miniature effect
        if (g_keys['0']) {
            if (g_keys[0x10]) {
                g_tilt_shift = @max(0.0, g_tilt_shift - 0.1);
            } else {
                g_tilt_shift = @min(1.0, g_tilt_shift + 0.1);
            }
            camera_moved = true; g_keys['0'] = false;
        }
        // Z - Glitter/sparkle intensity
        if (g_keys['Z']) {
            if (g_keys[0x10]) {
                g_glitter = @max(0.0, g_glitter - 0.1);
            } else {
                g_glitter = @min(1.0, g_glitter + 0.1);
            }
            camera_moved = true; g_keys['Z'] = false;
        }
        // X - Heat haze distortion
        if (g_keys['X']) {
            if (g_keys[0x10]) {
                g_heat_haze = @max(0.0, g_heat_haze - 0.05);
            } else {
                g_heat_haze = @min(0.5, g_heat_haze + 0.05);
            }
            camera_moved = true; g_keys['X'] = false;
        }
        // ============ MEGA EFFECTS BATCH 2 CONTROLS ============
        // F1 - Kaleidoscope (segments)
        if (g_keys[win32.VK_F1]) {
            if (g_keys[0x10]) {
                g_kaleidoscope = @max(0.0, g_kaleidoscope - 1.0);
            } else {
                g_kaleidoscope = @min(12.0, g_kaleidoscope + 1.0);
            }
            camera_moved = true; g_keys[win32.VK_F1] = false;
        }
        // F2 - Pixelation
        if (g_keys[win32.VK_F2]) {
            if (g_keys[0x10]) {
                g_pixelate = @max(0.0, g_pixelate - 0.1);
            } else {
                g_pixelate = @min(1.0, g_pixelate + 0.1);
            }
            camera_moved = true; g_keys[win32.VK_F2] = false;
        }
        // F3 - Edge detection / toon
        if (g_keys[win32.VK_F3]) {
            if (g_keys[0x10]) {
                g_edge_detect = @max(0.0, g_edge_detect - 0.1);
            } else {
                g_edge_detect = @min(1.0, g_edge_detect + 0.1);
            }
            camera_moved = true; g_keys[win32.VK_F3] = false;
        }
        // F4 - Halftone / comic
        if (g_keys[win32.VK_F4]) {
            if (g_keys[0x10]) {
                g_halftone = @max(0.0, g_halftone - 0.1);
            } else {
                g_halftone = @min(1.0, g_halftone + 0.1);
            }
            camera_moved = true; g_keys[win32.VK_F4] = false;
        }
        // F5 - Night vision
        if (g_keys[win32.VK_F5]) {
            if (g_keys[0x10]) {
                g_night_vision = @max(0.0, g_night_vision - 0.1);
            } else {
                g_night_vision = @min(1.0, g_night_vision + 0.1);
            }
            camera_moved = true; g_keys[win32.VK_F5] = false;
        }
        // F6 - Thermal vision
        if (g_keys[win32.VK_F6]) {
            if (g_keys[0x10]) {
                g_thermal = @max(0.0, g_thermal - 0.1);
            } else {
                g_thermal = @min(1.0, g_thermal + 0.1);
            }
            camera_moved = true; g_keys[win32.VK_F6] = false;
        }
        // F7 - Underwater
        if (g_keys[win32.VK_F7]) {
            if (g_keys[0x10]) {
                g_underwater = @max(0.0, g_underwater - 0.1);
            } else {
                g_underwater = @min(1.0, g_underwater + 0.1);
            }
            camera_moved = true; g_keys[win32.VK_F7] = false;
        }
        // F8 - Rain drops
        if (g_keys[win32.VK_F8]) {
            if (g_keys[0x10]) {
                g_rain_drops = @max(0.0, g_rain_drops - 0.1);
            } else {
                g_rain_drops = @min(1.0, g_rain_drops + 0.1);
            }
            camera_moved = true; g_keys[win32.VK_F8] = false;
        }
        // F9 - VHS effect
        if (g_keys[win32.VK_F9]) {
            if (g_keys[0x10]) {
                g_vhs_effect = @max(0.0, g_vhs_effect - 0.1);
            } else {
                g_vhs_effect = @min(1.0, g_vhs_effect + 0.1);
            }
            camera_moved = true; g_keys[win32.VK_F9] = false;
        }
        // F10 - 3D Anaglyph
        if (g_keys[win32.VK_F10]) {
            if (g_keys[0x10]) {
                g_anaglyph_3d = @max(0.0, g_anaglyph_3d - 0.1);
            } else {
                g_anaglyph_3d = @min(1.0, g_anaglyph_3d + 0.1);
            }
            camera_moved = true; g_keys[win32.VK_F10] = false;
        }
        // F11 - Fisheye
        if (g_keys[win32.VK_F11]) {
            if (g_keys[0x10]) {
                g_fisheye = @max(0.0, g_fisheye - 0.1);
            } else {
                g_fisheye = @min(1.0, g_fisheye + 0.1);
            }
            camera_moved = true; g_keys[win32.VK_F11] = false;
        }
        // Q - Posterize (levels 2-16)
        if (g_keys['Q']) {
            if (g_keys[0x10]) {
                g_posterize = @max(0.0, g_posterize - 1.0);
            } else {
                g_posterize = @min(16.0, g_posterize + 1.0);
            }
            camera_moved = true; g_keys['Q'] = false;
        }
        // [ - Sepia
        if (g_keys[0xDB]) { // VK_OEM_4 = [
            if (g_keys[0x10]) {
                g_sepia = @max(0.0, g_sepia - 0.1);
            } else {
                g_sepia = @min(1.0, g_sepia + 0.1);
            }
            camera_moved = true; g_keys[0xDB] = false;
        }
        // ] - Frosted glass
        if (g_keys[0xDD]) { // VK_OEM_6 = ]
            if (g_keys[0x10]) {
                g_frosted = @max(0.0, g_frosted - 0.1);
            } else {
                g_frosted = @min(1.0, g_frosted + 0.1);
            }
            camera_moved = true; g_keys[0xDD] = false;
        }
        // \ - Radial blur
        if (g_keys[0xDC]) { // VK_OEM_5 = backslash
            if (g_keys[0x10]) {
                g_radial_blur = @max(0.0, g_radial_blur - 0.1);
            } else {
                g_radial_blur = @min(1.0, g_radial_blur + 0.1);
            }
            camera_moved = true; g_keys[0xDC] = false;
        }
        // ; - Dithering
        if (g_keys[0xBA]) { // VK_OEM_1 = ;
            if (g_keys[0x10]) {
                g_dither = @max(0.0, g_dither - 0.1);
            } else {
                g_dither = @min(1.0, g_dither + 0.1);
            }
            camera_moved = true; g_keys[0xBA] = false;
        }
        // ' - Holographic
        if (g_keys[0xDE]) { // VK_OEM_7 = '
            if (g_keys[0x10]) {
                g_holographic = @max(0.0, g_holographic - 0.1);
            } else {
                g_holographic = @min(1.0, g_holographic + 0.1);
            }
            camera_moved = true; g_keys[0xDE] = false;
        }
        // , - ASCII mode
        if (g_keys[0xBC]) { // VK_OEM_COMMA
            if (g_keys[0x10]) {
                g_ascii_mode = @max(0.0, g_ascii_mode - 0.1);
            } else {
                g_ascii_mode = @min(1.0, g_ascii_mode + 0.1);
            }
            camera_moved = true; g_keys[0xBC] = false;
        }
        // TAB - Toggle HUD
        if (g_keys[win32.VK_TAB]) {
            g_show_hud = !g_show_hud;
            g_keys[win32.VK_TAB] = false;
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
        glUniform1f(u_displacement_loc, g_displacement);
        glUniform1f(u_denoise_loc, g_denoise_strength);
        glUniform1f(u_fog_density_loc, g_fog_density);
        glUniform3f(u_fog_color_loc, g_fog_color[0], g_fog_color[1], g_fog_color[2]);
        glUniform1f(u_film_grain_loc, g_film_grain);
        glUniform1f(u_dispersion_loc, g_dispersion);
        glUniform1f(u_lens_flare_loc, g_lens_flare);
        glUniform1f(u_iridescence_loc, g_iridescence);
        glUniform1f(u_anisotropy_loc, g_anisotropy);
        glUniform1f(u_color_temp_loc, g_color_temp);
        glUniform1f(u_saturation_loc, g_saturation);
        glUniform1f(u_scanlines_loc, g_scanlines);
        glUniform1f(u_tilt_shift_loc, g_tilt_shift);
        glUniform1f(u_glitter_loc, g_glitter);
        glUniform1f(u_heat_haze_loc, g_heat_haze);
        // MEGA EFFECTS BATCH 2 uniforms
        glUniform1f(u_kaleidoscope_loc, g_kaleidoscope);
        glUniform1f(u_pixelate_loc, g_pixelate);
        glUniform1f(u_edge_detect_loc, g_edge_detect);
        glUniform1f(u_halftone_loc, g_halftone);
        glUniform1f(u_night_vision_loc, g_night_vision);
        glUniform1f(u_thermal_loc, g_thermal);
        glUniform1f(u_underwater_loc, g_underwater);
        glUniform1f(u_rain_drops_loc, g_rain_drops);
        glUniform1f(u_vhs_effect_loc, g_vhs_effect);
        glUniform1f(u_anaglyph_3d_loc, g_anaglyph_3d);
        glUniform1f(u_fisheye_loc, g_fisheye);
        glUniform1f(u_posterize_loc, g_posterize);
        glUniform1f(u_sepia_loc, g_sepia);
        glUniform1f(u_frosted_loc, g_frosted);
        glUniform1f(u_radial_blur_loc, g_radial_blur);
        glUniform1f(u_dither_loc, g_dither);
        glUniform1f(u_holographic_loc, g_holographic);
        glUniform1f(u_ascii_mode_loc, g_ascii_mode);
        glUniform1i(u_bokeh_shape_loc, g_bokeh_shape);
        glUniform1i(u_debug_mode_loc, g_debug_mode);
        glUniform1i(u_instance_bvh_root_loc, -1); // -1 = linear search, no BVH

        const groups_x = (RENDER_WIDTH + 15) / 16;
        const groups_y = (RENDER_HEIGHT + 15) / 16;

        var sample_idx: u32 = 0;
        while (sample_idx < g_samples_per_frame) : (sample_idx += 1) {
            glUniform1ui(u_sample_loc, sample_idx);
            glDispatchCompute(groups_x, groups_y, 1);
            glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);
        }

        gl.glDisable(gl.GL_BLEND);  // Ensure blending is off BEFORE clear
        gl.glClear(gl.GL_COLOR_BUFFER_BIT);
        gl.glColor4f(1.0, 1.0, 1.0, 1.0);  // Full opacity for texture
        gl.glEnable(GL_TEXTURE_2D);
        gl.glBindTexture(GL_TEXTURE_2D, output_texture);
        gl.glBegin(gl.GL_QUADS);
        gl.glTexCoord2f(0, 1); gl.glVertex2f(-1, -1);
        gl.glTexCoord2f(1, 1); gl.glVertex2f(1, -1);
        gl.glTexCoord2f(1, 0); gl.glVertex2f(1, 1);
        gl.glTexCoord2f(0, 0); gl.glVertex2f(-1, 1);
        gl.glEnd();

        // Render HUD overlay
        hud.render(@intCast(RENDER_WIDTH), @intCast(RENDER_HEIGHT), .{
            .fov = g_fov,
            .aperture = g_aperture,
            .focus_dist = g_focus_dist,
            .samples_per_frame = g_samples_per_frame,
            .flight_mode = g_flight_mode,
            .camera_roll = g_camera_roll,
            .debug_mode = g_debug_mode,
            .bloom_strength = g_bloom_strength,
            .exposure = g_exposure,
            .chromatic_strength = g_chromatic_strength,
            .vignette_strength = g_vignette_strength,
            .film_grain = g_film_grain,
            .lens_flare = g_lens_flare,
            .dispersion = g_dispersion,
            .heat_haze = g_heat_haze,
            .scanlines = g_scanlines,
            .tilt_shift = g_tilt_shift,
            .sepia = g_sepia,
            .dither = g_dither,
            .night_vision = g_night_vision,
            .thermal = g_thermal,
            .underwater = g_underwater,
            .fisheye = g_fisheye,
            .kaleidoscope = g_kaleidoscope,
            .pixelate = g_pixelate,
            .halftone = g_halftone,
            .vhs_effect = g_vhs_effect,
            .anaglyph_3d = g_anaglyph_3d,
        }, g_show_hud); // Press TAB to toggle HUD

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
    const sources = [_][*]const GLchar{shader_module.compute_shader_source};
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
