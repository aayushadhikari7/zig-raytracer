const std = @import("std");
const shader_module = @import("shader.zig");

// ============================================================================
// SHADER LOADER - Load from file with hot reload support
// ============================================================================

const gl = @cImport({
    @cInclude("GL/gl.h");
});

const win32 = @cImport({
    @cDefine("WIN32_LEAN_AND_MEAN", "1");
    @cInclude("windows.h");
});

// OpenGL constants
const GL_COMPUTE_SHADER: c_uint = 0x91B9;
const GL_COMPILE_STATUS: c_uint = 0x8B81;
const GL_LINK_STATUS: c_uint = 0x8B82;
const GL_INFO_LOG_LENGTH: c_uint = 0x8B84;
const GL_TRUE: u8 = 1;

// Function pointer types
const PFNGLCREATESHADERPROC = *const fn (c_uint) callconv(.c) c_uint;
const PFNGLSHADERSOURCEPROC = *const fn (c_uint, c_int, [*]const [*]const u8, ?[*]const c_int) callconv(.c) void;
const PFNGLCOMPILESHADERPROC = *const fn (c_uint) callconv(.c) void;
const PFNGLGETSHADERIVPROC = *const fn (c_uint, c_uint, *c_int) callconv(.c) void;
const PFNGLGETSHADERINFOLOGPROC = *const fn (c_uint, c_int, ?*c_int, [*]u8) callconv(.c) void;
const PFNGLCREATEPROGRAMPROC = *const fn () callconv(.c) c_uint;
const PFNGLATTACHSHADERPROC = *const fn (c_uint, c_uint) callconv(.c) void;
const PFNGLLINKPROGRAMPROC = *const fn (c_uint) callconv(.c) void;
const PFNGLGETPROGRAMIVPROC = *const fn (c_uint, c_uint, *c_int) callconv(.c) void;
const PFNGLGETPROGRAMINFOLOGPROC = *const fn (c_uint, c_int, ?*c_int, [*]u8) callconv(.c) void;
const PFNGLDELETESHADERPROC = *const fn (c_uint) callconv(.c) void;
const PFNGLDELETEPROGRAMPROC = *const fn (c_uint) callconv(.c) void;

extern "opengl32" fn wglGetProcAddress([*:0]const u8) callconv(.c) ?*anyopaque;

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
var glDeleteShader: PFNGLDELETESHADERPROC = undefined;
var glDeleteProgram: PFNGLDELETEPROGRAMPROC = undefined;

var gl_initialized = false;

fn initGL() void {
    if (gl_initialized) return;
    glCreateShader = @ptrCast(wglGetProcAddress("glCreateShader"));
    glShaderSource = @ptrCast(wglGetProcAddress("glShaderSource"));
    glCompileShader = @ptrCast(wglGetProcAddress("glCompileShader"));
    glGetShaderiv = @ptrCast(wglGetProcAddress("glGetShaderiv"));
    glGetShaderInfoLog = @ptrCast(wglGetProcAddress("glGetShaderInfoLog"));
    glCreateProgram = @ptrCast(wglGetProcAddress("glCreateProgram"));
    glAttachShader = @ptrCast(wglGetProcAddress("glAttachShader"));
    glLinkProgram = @ptrCast(wglGetProcAddress("glLinkProgram"));
    glGetProgramiv = @ptrCast(wglGetProcAddress("glGetProgramiv"));
    glGetProgramInfoLog = @ptrCast(wglGetProcAddress("glGetProgramInfoLog"));
    glDeleteShader = @ptrCast(wglGetProcAddress("glDeleteShader"));
    glDeleteProgram = @ptrCast(wglGetProcAddress("glDeleteProgram"));
    gl_initialized = true;
}

pub const SHADER_FILE = "shader.glsl";

var last_shader_mod_time: ?std.Io.Timestamp = null;
var current_program: c_uint = 0;
var last_error: ?[]const u8 = null;

// Get IO instance for file operations
fn getIo() std.Io {
    return std.Io.Threaded.global_single_threaded.io();
}

pub fn getShaderPath(allocator: std.mem.Allocator) ![]u8 {
    // Just return a copy of the shader filename - we use relative paths with cwd
    return try allocator.dupe(u8, SHADER_FILE);
}

pub fn loadShaderFromFile(allocator: std.mem.Allocator) ![]u8 {
    const io = getIo();
    const cwd = std.Io.Dir.cwd();

    const file = cwd.openFile(io, SHADER_FILE, .{}) catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print("Shader file not found, using embedded shader\n", .{});
            return error.FileNotFound;
        }
        return err;
    };
    defer file.close(io);

    const stat = file.stat(io) catch return error.FileNotFound;
    last_shader_mod_time = stat.mtime;

    // Read file contents
    var read_buf: [8192]u8 = undefined;
    var reader = file.reader(io, &read_buf);
    return reader.interface.allocRemaining(allocator, std.Io.Limit.limited(10 * 1024 * 1024)) catch return error.FileNotFound;
}

pub fn checkShaderModified(allocator: std.mem.Allocator) bool {
    _ = allocator;
    const io = getIo();
    const cwd = std.Io.Dir.cwd();

    const file = cwd.openFile(io, SHADER_FILE, .{}) catch return false;
    defer file.close(io);

    const stat = file.stat(io) catch return false;
    const new_mtime = stat.mtime;
    if (last_shader_mod_time) |old_mtime| {
        // Compare timestamps using nanoseconds
        if (new_mtime.toNanoseconds() != old_mtime.toNanoseconds()) {
            last_shader_mod_time = new_mtime;
            return true;
        }
    } else {
        last_shader_mod_time = new_mtime;
    }
    return false;
}

pub fn compileShader(allocator: std.mem.Allocator, source: []const u8) !c_uint {
    initGL();

    const shader = glCreateShader(GL_COMPUTE_SHADER);
    if (shader == 0) return error.ShaderCreationFailed;

    // Need null-terminated string
    const source_z = try allocator.allocSentinel(u8, source.len, 0);
    defer allocator.free(source_z);
    @memcpy(source_z, source);

    const sources = [_][*]const u8{source_z.ptr};
    glShaderSource(shader, 1, &sources, null);
    glCompileShader(shader);

    var success: c_int = 0;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &success);

    if (success != GL_TRUE) {
        var log_len: c_int = 0;
        glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &log_len);

        if (log_len > 0) {
            const log = try allocator.alloc(u8, @intCast(log_len));
            glGetShaderInfoLog(shader, log_len, null, log.ptr);
            std.debug.print("Shader compile error:\n{s}\n", .{log});
            if (last_error) |e| allocator.free(e);
            last_error = log;
        }

        glDeleteShader(shader);
        return error.ShaderCompileFailed;
    }

    // Create program
    const program = glCreateProgram();
    glAttachShader(program, shader);
    glLinkProgram(program);

    glGetProgramiv(program, GL_LINK_STATUS, &success);
    if (success != GL_TRUE) {
        var log_len: c_int = 0;
        glGetProgramiv(program, GL_INFO_LOG_LENGTH, &log_len);

        if (log_len > 0) {
            const log = try allocator.alloc(u8, @intCast(log_len));
            glGetProgramInfoLog(program, log_len, null, log.ptr);
            std.debug.print("Program link error:\n{s}\n", .{log});
            if (last_error) |e| allocator.free(e);
            last_error = log;
        }

        glDeleteShader(shader);
        glDeleteProgram(program);
        return error.ProgramLinkFailed;
    }

    glDeleteShader(shader);
    std.debug.print("Shader compiled successfully!\n", .{});

    if (last_error) |e| {
        allocator.free(e);
        last_error = null;
    }

    return program;
}

pub fn loadAndCompileShader(allocator: std.mem.Allocator) !c_uint {
    // Try loading from file first
    const source = loadShaderFromFile(allocator) catch {
        // Fall back to embedded shader
        const len = std.mem.len(shader_module.compute_shader_source);
        return try compileShader(allocator, shader_module.compute_shader_source[0..len]);
    };
    defer allocator.free(source);

    return try compileShader(allocator, source);
}

pub fn hotReload(allocator: std.mem.Allocator) ?c_uint {
    if (!checkShaderModified(allocator)) return null;

    std.debug.print("Shader file changed, reloading...\n", .{});

    const source = loadShaderFromFile(allocator) catch |err| {
        std.debug.print("Failed to load shader: {}\n", .{err});
        return null;
    };
    defer allocator.free(source);

    const new_program = compileShader(allocator, source) catch |err| {
        std.debug.print("Failed to compile shader: {}\n", .{err});
        return null;
    };

    // Delete old program if we had one
    if (current_program != 0) {
        glDeleteProgram(current_program);
    }
    current_program = new_program;

    return new_program;
}

pub fn getLastError() ?[]const u8 {
    return last_error;
}

pub fn exportEmbeddedShader(allocator: std.mem.Allocator) !void {
    _ = allocator;
    const io = getIo();
    const cwd = std.Io.Dir.cwd();

    const file = try cwd.createFile(io, SHADER_FILE, .{});
    defer file.close(io);

    const len = std.mem.len(shader_module.compute_shader_source);
    try file.writeStreamingAll(io, shader_module.compute_shader_source[0..len]);

    std.debug.print("Exported embedded shader to: {s}\n", .{SHADER_FILE});
}
