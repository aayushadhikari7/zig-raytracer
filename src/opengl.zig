const std = @import("std");

// ============================================================================
// OPENGL MODULE - All OpenGL bindings and function pointers
// ============================================================================

// Basic OpenGL from system
pub const gl = @cImport({
    @cInclude("GL/gl.h");
});

// Type aliases
pub const GLuint = c_uint;
pub const GLint = c_int;
pub const GLsizei = c_int;
pub const GLenum = c_uint;
pub const GLchar = u8;
pub const GLboolean = u8;
pub const GLsizeiptr = isize;

// OpenGL constants
pub const GL_COMPUTE_SHADER: GLenum = 0x91B9;
pub const GL_SHADER_STORAGE_BUFFER: GLenum = 0x90D2;
pub const GL_DYNAMIC_DRAW: GLenum = 0x88E8;
pub const GL_TEXTURE_2D: GLenum = 0x0DE1;
pub const GL_RGBA32F: GLenum = 0x8814;
pub const GL_RGBA: GLenum = 0x1908;
pub const GL_FLOAT: GLenum = 0x1406;
pub const GL_READ_WRITE: GLenum = 0x88BA;
pub const GL_SHADER_IMAGE_ACCESS_BARRIER_BIT: GLenum = 0x00000020;
pub const GL_TEXTURE_MAG_FILTER: GLenum = 0x2800;
pub const GL_TEXTURE_MIN_FILTER: GLenum = 0x2801;
pub const GL_LINEAR: GLenum = 0x2601;
pub const GL_COMPILE_STATUS: GLenum = 0x8B81;
pub const GL_LINK_STATUS: GLenum = 0x8B82;
pub const GL_INFO_LOG_LENGTH: GLenum = 0x8B84;
pub const GL_TRUE: GLboolean = 1;

// OpenGL function pointer types
pub const PFNGLCREATESHADERPROC = *const fn (GLenum) callconv(.c) GLuint;
pub const PFNGLSHADERSOURCEPROC = *const fn (GLuint, GLsizei, [*]const [*]const GLchar, ?[*]const GLint) callconv(.c) void;
pub const PFNGLCOMPILESHADERPROC = *const fn (GLuint) callconv(.c) void;
pub const PFNGLGETSHADERIVPROC = *const fn (GLuint, GLenum, *GLint) callconv(.c) void;
pub const PFNGLGETSHADERINFOLOGPROC = *const fn (GLuint, GLsizei, ?*GLsizei, [*]GLchar) callconv(.c) void;
pub const PFNGLCREATEPROGRAMPROC = *const fn () callconv(.c) GLuint;
pub const PFNGLATTACHSHADERPROC = *const fn (GLuint, GLuint) callconv(.c) void;
pub const PFNGLLINKPROGRAMPROC = *const fn (GLuint) callconv(.c) void;
pub const PFNGLGETPROGRAMIVPROC = *const fn (GLuint, GLenum, *GLint) callconv(.c) void;
pub const PFNGLGETPROGRAMINFOLOGPROC = *const fn (GLuint, GLsizei, ?*GLsizei, [*]GLchar) callconv(.c) void;
pub const PFNGLUSEPROGRAMPROC = *const fn (GLuint) callconv(.c) void;
pub const PFNGLDELETESHADERPROC = *const fn (GLuint) callconv(.c) void;
pub const PFNGLDISPATCHCOMPUTEPROC = *const fn (GLuint, GLuint, GLuint) callconv(.c) void;
pub const PFNGLMEMORYBARRIERPROC = *const fn (GLenum) callconv(.c) void;
pub const PFNGLBINDIMAGETEXTUREPROC = *const fn (GLuint, GLuint, GLint, GLboolean, GLint, GLenum, GLenum) callconv(.c) void;
pub const PFNGLGETUNIFORMLOCATIONPROC = *const fn (GLuint, [*]const GLchar) callconv(.c) GLint;
pub const PFNGLUNIFORM1IPROC = *const fn (GLint, GLint) callconv(.c) void;
pub const PFNGLUNIFORM1FPROC = *const fn (GLint, f32) callconv(.c) void;
pub const PFNGLUNIFORM1UIPROC = *const fn (GLint, GLuint) callconv(.c) void;
pub const PFNGLUNIFORM3FPROC = *const fn (GLint, f32, f32, f32) callconv(.c) void;
pub const PFNGLGENBUFFERSPROC = *const fn (GLsizei, *GLuint) callconv(.c) void;
pub const PFNGLBINDBUFFERPROC = *const fn (GLenum, GLuint) callconv(.c) void;
pub const PFNGLBUFFERDATAPROC = *const fn (GLenum, GLsizeiptr, ?*const anyopaque, GLenum) callconv(.c) void;
pub const PFNGLBINDBUFFERBASEPROC = *const fn (GLenum, GLuint, GLuint) callconv(.c) void;
pub const PFNGLACTIVETEXTUREPROC = *const fn (GLenum) callconv(.c) void;

// Global GL function pointers
pub var glCreateShader: PFNGLCREATESHADERPROC = undefined;
pub var glShaderSource: PFNGLSHADERSOURCEPROC = undefined;
pub var glCompileShader: PFNGLCOMPILESHADERPROC = undefined;
pub var glGetShaderiv: PFNGLGETSHADERIVPROC = undefined;
pub var glGetShaderInfoLog: PFNGLGETSHADERINFOLOGPROC = undefined;
pub var glCreateProgram: PFNGLCREATEPROGRAMPROC = undefined;
pub var glAttachShader: PFNGLATTACHSHADERPROC = undefined;
pub var glLinkProgram: PFNGLLINKPROGRAMPROC = undefined;
pub var glGetProgramiv: PFNGLGETPROGRAMIVPROC = undefined;
pub var glGetProgramInfoLog: PFNGLGETPROGRAMINFOLOGPROC = undefined;
pub var glUseProgram: PFNGLUSEPROGRAMPROC = undefined;
pub var glDeleteShader: PFNGLDELETESHADERPROC = undefined;
pub var glDispatchCompute: PFNGLDISPATCHCOMPUTEPROC = undefined;
pub var glMemoryBarrier: PFNGLMEMORYBARRIERPROC = undefined;
pub var glBindImageTexture: PFNGLBINDIMAGETEXTUREPROC = undefined;
pub var glGetUniformLocation: PFNGLGETUNIFORMLOCATIONPROC = undefined;
pub var glUniform1i: PFNGLUNIFORM1IPROC = undefined;
pub var glUniform1f: PFNGLUNIFORM1FPROC = undefined;
pub var glUniform1ui: PFNGLUNIFORM1UIPROC = undefined;
pub var glUniform3f: PFNGLUNIFORM3FPROC = undefined;
pub var glGenBuffers: PFNGLGENBUFFERSPROC = undefined;
pub var glBindBuffer: PFNGLBINDBUFFERPROC = undefined;
pub var glBufferData: PFNGLBUFFERDATAPROC = undefined;
pub var glBindBufferBase: PFNGLBINDBUFFERBASEPROC = undefined;
pub var glActiveTexture: PFNGLACTIVETEXTUREPROC = undefined;

// WGL types and functions
pub const HGLRC = *anyopaque;
pub const PFNWGLCREATECONTEXTATTRIBSARBPROC = *const fn (?*anyopaque, ?HGLRC, ?[*]const c_int) callconv(.c) ?HGLRC;
pub const PFNWGLSWAPINTERVALEXTPROC = *const fn (c_int) callconv(.c) c_int;

pub extern "opengl32" fn wglCreateContext(?*anyopaque) callconv(.c) ?HGLRC;
pub extern "opengl32" fn wglMakeCurrent(?*anyopaque, ?HGLRC) callconv(.c) c_int;
pub extern "opengl32" fn wglDeleteContext(HGLRC) callconv(.c) c_int;
pub extern "opengl32" fn wglGetProcAddress([*:0]const u8) callconv(.c) ?*anyopaque;

pub const WGL_CONTEXT_MAJOR_VERSION_ARB: c_int = 0x2091;
pub const WGL_CONTEXT_MINOR_VERSION_ARB: c_int = 0x2092;
pub const WGL_CONTEXT_PROFILE_MASK_ARB: c_int = 0x9126;
pub const WGL_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB: c_int = 0x00000002;

// Load all GL extension functions
pub fn loadFunctions() !void {
    inline for (.{
        .{ "glCreateShader", &glCreateShader },
        .{ "glShaderSource", &glShaderSource },
        .{ "glCompileShader", &glCompileShader },
        .{ "glGetShaderiv", &glGetShaderiv },
        .{ "glGetShaderInfoLog", &glGetShaderInfoLog },
        .{ "glCreateProgram", &glCreateProgram },
        .{ "glAttachShader", &glAttachShader },
        .{ "glLinkProgram", &glLinkProgram },
        .{ "glGetProgramiv", &glGetProgramiv },
        .{ "glGetProgramInfoLog", &glGetProgramInfoLog },
        .{ "glUseProgram", &glUseProgram },
        .{ "glDeleteShader", &glDeleteShader },
        .{ "glDispatchCompute", &glDispatchCompute },
        .{ "glMemoryBarrier", &glMemoryBarrier },
        .{ "glBindImageTexture", &glBindImageTexture },
        .{ "glGetUniformLocation", &glGetUniformLocation },
        .{ "glUniform1i", &glUniform1i },
        .{ "glUniform1f", &glUniform1f },
        .{ "glUniform1ui", &glUniform1ui },
        .{ "glUniform3f", &glUniform3f },
        .{ "glGenBuffers", &glGenBuffers },
        .{ "glBindBuffer", &glBindBuffer },
        .{ "glBufferData", &glBufferData },
        .{ "glBindBufferBase", &glBindBufferBase },
        .{ "glActiveTexture", &glActiveTexture },
    }) |entry| {
        const name = entry[0];
        const ptr = entry[1];
        const func = wglGetProcAddress(name);
        if (func) |f| {
            ptr.* = @ptrCast(f);
        } else {
            std.debug.print("Failed to load GL function: {s}\n", .{name});
            return error.GLFunctionNotFound;
        }
    }
}
