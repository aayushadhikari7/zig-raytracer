const std = @import("std");

const win32 = @cImport({
    @cDefine("WIN32_LEAN_AND_MEAN", "1");
    @cInclude("windows.h");
});

pub const gl = @cImport({
    @cInclude("GL/gl.h");
});

// OpenGL types
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

// OpenGL function types
const CC = std.builtin.CallingConvention.c;
pub const PFNGLCREATESHADERPROC = *const fn (GLenum) callconv(CC) GLuint;
pub const PFNGLSHADERSOURCEPROC = *const fn (GLuint, GLsizei, [*]const [*]const GLchar, ?[*]const GLint) callconv(CC) void;
pub const PFNGLCOMPILESHADERPROC = *const fn (GLuint) callconv(CC) void;
pub const PFNGLGETSHADERIVPROC = *const fn (GLuint, GLenum, *GLint) callconv(CC) void;
pub const PFNGLGETSHADERINFOLOGPROC = *const fn (GLuint, GLsizei, ?*GLsizei, [*]GLchar) callconv(CC) void;
pub const PFNGLCREATEPROGRAMPROC = *const fn () callconv(CC) GLuint;
pub const PFNGLATTACHSHADERPROC = *const fn (GLuint, GLuint) callconv(CC) void;
pub const PFNGLLINKPROGRAMPROC = *const fn (GLuint) callconv(CC) void;
pub const PFNGLGETPROGRAMIVPROC = *const fn (GLuint, GLenum, *GLint) callconv(CC) void;
pub const PFNGLGETPROGRAMINFOLOGPROC = *const fn (GLuint, GLsizei, ?*GLsizei, [*]GLchar) callconv(CC) void;
pub const PFNGLUSEPROGRAMPROC = *const fn (GLuint) callconv(CC) void;
pub const PFNGLDELETESHADERPROC = *const fn (GLuint) callconv(CC) void;
pub const PFNGLDISPATCHCOMPUTEPROC = *const fn (GLuint, GLuint, GLuint) callconv(CC) void;
pub const PFNGLMEMORYBARRIERPROC = *const fn (GLenum) callconv(CC) void;
pub const PFNGLBINDIMAGETEXTUREPROC = *const fn (GLuint, GLuint, GLint, GLboolean, GLint, GLenum, GLenum) callconv(CC) void;
pub const PFNGLGETUNIFORMLOCATIONPROC = *const fn (GLuint, [*]const GLchar) callconv(CC) GLint;
pub const PFNGLUNIFORM1IPROC = *const fn (GLint, GLint) callconv(CC) void;
pub const PFNGLUNIFORM1FPROC = *const fn (GLint, f32) callconv(CC) void;
pub const PFNGLUNIFORM1UIPROC = *const fn (GLint, GLuint) callconv(CC) void;
pub const PFNGLUNIFORM3FPROC = *const fn (GLint, f32, f32, f32) callconv(CC) void;
pub const PFNGLGENBUFFERSPROC = *const fn (GLsizei, *GLuint) callconv(CC) void;
pub const PFNGLBINDBUFFERPROC = *const fn (GLenum, GLuint) callconv(CC) void;
pub const PFNGLBUFFERDATAPROC = *const fn (GLenum, GLsizeiptr, ?*const anyopaque, GLenum) callconv(CC) void;
pub const PFNGLBINDBUFFERBASEPROC = *const fn (GLenum, GLuint, GLuint) callconv(CC) void;
pub const PFNGLACTIVETEXTUREPROC = *const fn (GLenum) callconv(CC) void;

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
pub const PFNWGLCREATECONTEXTATTRIBSARBPROC = *const fn (win32.HDC, ?HGLRC, ?[*]const c_int) callconv(CC) ?HGLRC;
pub const PFNWGLSWAPINTERVALEXTPROC = *const fn (c_int) callconv(CC) c_int;

pub extern "opengl32" fn wglCreateContext(win32.HDC) callconv(CC) ?HGLRC;
pub extern "opengl32" fn wglMakeCurrent(win32.HDC, ?HGLRC) callconv(CC) c_int;
pub extern "opengl32" fn wglDeleteContext(HGLRC) callconv(CC) c_int;
pub extern "opengl32" fn wglGetProcAddress([*:0]const u8) callconv(CC) ?*anyopaque;

pub const WGL_CONTEXT_MAJOR_VERSION_ARB: c_int = 0x2091;
pub const WGL_CONTEXT_MINOR_VERSION_ARB: c_int = 0x2092;
pub const WGL_CONTEXT_PROFILE_MASK_ARB: c_int = 0x9126;
pub const WGL_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB: c_int = 0x00000002;

fn getProc(comptime T: type, name: [*:0]const u8) T {
    return @ptrCast(wglGetProcAddress(name) orelse @panic("Failed to load GL function"));
}

pub fn loadGLFunctions() void {
    glCreateShader = getProc(PFNGLCREATESHADERPROC, "glCreateShader");
    glShaderSource = getProc(PFNGLSHADERSOURCEPROC, "glShaderSource");
    glCompileShader = getProc(PFNGLCOMPILESHADERPROC, "glCompileShader");
    glGetShaderiv = getProc(PFNGLGETSHADERIVPROC, "glGetShaderiv");
    glGetShaderInfoLog = getProc(PFNGLGETSHADERINFOLOGPROC, "glGetShaderInfoLog");
    glCreateProgram = getProc(PFNGLCREATEPROGRAMPROC, "glCreateProgram");
    glAttachShader = getProc(PFNGLATTACHSHADERPROC, "glAttachShader");
    glLinkProgram = getProc(PFNGLLINKPROGRAMPROC, "glLinkProgram");
    glGetProgramiv = getProc(PFNGLGETPROGRAMIVPROC, "glGetProgramiv");
    glGetProgramInfoLog = getProc(PFNGLGETPROGRAMINFOLOGPROC, "glGetProgramInfoLog");
    glUseProgram = getProc(PFNGLUSEPROGRAMPROC, "glUseProgram");
    glDeleteShader = getProc(PFNGLDELETESHADERPROC, "glDeleteShader");
    glDispatchCompute = getProc(PFNGLDISPATCHCOMPUTEPROC, "glDispatchCompute");
    glMemoryBarrier = getProc(PFNGLMEMORYBARRIERPROC, "glMemoryBarrier");
    glBindImageTexture = getProc(PFNGLBINDIMAGETEXTUREPROC, "glBindImageTexture");
    glGetUniformLocation = getProc(PFNGLGETUNIFORMLOCATIONPROC, "glGetUniformLocation");
    glUniform1i = getProc(PFNGLUNIFORM1IPROC, "glUniform1i");
    glUniform1f = getProc(PFNGLUNIFORM1FPROC, "glUniform1f");
    glUniform1ui = getProc(PFNGLUNIFORM1UIPROC, "glUniform1ui");
    glUniform3f = getProc(PFNGLUNIFORM3FPROC, "glUniform3f");
    glGenBuffers = getProc(PFNGLGENBUFFERSPROC, "glGenBuffers");
    glBindBuffer = getProc(PFNGLBINDBUFFERPROC, "glBindBuffer");
    glBufferData = getProc(PFNGLBUFFERDATAPROC, "glBufferData");
    glBindBufferBase = getProc(PFNGLBINDBUFFERBASEPROC, "glBindBufferBase");
    glActiveTexture = getProc(PFNGLACTIVETEXTUREPROC, "glActiveTexture");
}

pub fn createComputeProgram(shader_source: [*]const u8) ?GLuint {
    const shader = glCreateShader(GL_COMPUTE_SHADER);
    const sources = [_][*]const GLchar{shader_source};
    glShaderSource(shader, 1, &sources, null);
    glCompileShader(shader);

    var success: GLint = 0;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
    if (success != GL_TRUE) {
        var log_len: GLint = 0;
        glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &log_len);
        if (log_len > 0) {
            var log: [8192]GLchar = undefined;
            glGetShaderInfoLog(shader, 8192, null, &log);
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
