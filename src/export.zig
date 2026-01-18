const std = @import("std");

// ============================================================================
// IMAGE EXPORT - PNG, BMP, HDR export functionality
// ============================================================================

const gl = @cImport({
    @cInclude("GL/gl.h");
});

fn getIo() std.Io {
    return std.Io.Threaded.global_single_threaded.io();
}

const PNG_SIGNATURE = [_]u8{ 0x89, 'P', 'N', 'G', '\r', '\n', 0x1A, '\n' };

fn crc32(data: []const u8) u32 {
    const table = comptime blk: {
        @setEvalBranchQuota(5000);
        var t: [256]u32 = undefined;
        for (0..256) |i| {
            var c: u32 = @intCast(i);
            for (0..8) |_| {
                if (c & 1 != 0) {
                    c = 0xEDB88320 ^ (c >> 1);
                } else {
                    c = c >> 1;
                }
            }
            t[i] = c;
        }
        break :blk t;
    };
    var crc: u32 = 0xFFFFFFFF;
    for (data) |b| {
        crc = table[(crc ^ b) & 0xFF] ^ (crc >> 8);
    }
    return ~crc;
}

fn adler32(data: []const u8) u32 {
    var a: u32 = 1;
    var b: u32 = 0;
    for (data) |byte| {
        a = (a + byte) % 65521;
        b = (b + a) % 65521;
    }
    return (b << 16) | a;
}

fn zlibCompress(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    try result.append(allocator, 0x78);
    try result.append(allocator, 0x01);

    var offset: usize = 0;
    while (offset < data.len) {
        const remaining = data.len - offset;
        const block_size = @min(remaining, 65535);
        const is_final: u8 = if (offset + block_size >= data.len) 1 else 0;

        try result.append(allocator, is_final);
        const len16: u16 = @intCast(block_size);
        try result.appendSlice(allocator, &std.mem.toBytes(len16));
        try result.appendSlice(allocator, &std.mem.toBytes(~len16));
        try result.appendSlice(allocator, data[offset .. offset + block_size]);
        offset += block_size;
    }

    const checksum = adler32(data);
    try result.appendSlice(allocator, &[_]u8{
        @intCast((checksum >> 24) & 0xFF),
        @intCast((checksum >> 16) & 0xFF),
        @intCast((checksum >> 8) & 0xFF),
        @intCast(checksum & 0xFF),
    });

    return result.toOwnedSlice(allocator);
}

fn writeChunkToList(allocator: std.mem.Allocator, list: *std.ArrayList(u8), chunk_type: *const [4]u8, data: []const u8) !void {
    const len: u32 = @intCast(data.len);
    try list.appendSlice(allocator, &std.mem.toBytes(std.mem.nativeToBig(u32, len)));

    var crc_data = std.ArrayList(u8){};
    defer crc_data.deinit(allocator);
    try crc_data.appendSlice(allocator, chunk_type);
    try crc_data.appendSlice(allocator, data);

    try list.appendSlice(allocator, chunk_type);
    try list.appendSlice(allocator, data);
    try list.appendSlice(allocator, &std.mem.toBytes(std.mem.nativeToBig(u32, crc32(crc_data.items))));
}

pub fn exportPNG(allocator: std.mem.Allocator, path: []const u8, width: u32, height: u32) !void {
    const io = getIo();
    const pixel_count = width * height;
    const pixels = try allocator.alloc(u8, pixel_count * 4);
    defer allocator.free(pixels);

    gl.glReadPixels(0, 0, @intCast(width), @intCast(height), gl.GL_RGBA, gl.GL_UNSIGNED_BYTE, pixels.ptr);

    const row_size = width * 4;
    const temp_row = try allocator.alloc(u8, row_size);
    defer allocator.free(temp_row);

    var y: usize = 0;
    while (y < height / 2) : (y += 1) {
        const top_row = y * row_size;
        const bottom_row = (height - 1 - y) * row_size;
        @memcpy(temp_row, pixels[top_row .. top_row + row_size]);
        @memcpy(pixels[top_row .. top_row + row_size], pixels[bottom_row .. bottom_row + row_size]);
        @memcpy(pixels[bottom_row .. bottom_row + row_size], temp_row);
    }

    const filtered_size = height * (1 + width * 4);
    const filtered = try allocator.alloc(u8, filtered_size);
    defer allocator.free(filtered);

    var dest_offset: usize = 0;
    for (0..height) |row| {
        filtered[dest_offset] = 0;
        dest_offset += 1;
        const src_offset = row * row_size;
        @memcpy(filtered[dest_offset .. dest_offset + row_size], pixels[src_offset .. src_offset + row_size]);
        dest_offset += row_size;
    }

    const compressed = try zlibCompress(allocator, filtered);
    defer allocator.free(compressed);

    const cwd = std.Io.Dir.cwd();
    const file = try cwd.createFile(io, path, .{});
    defer file.close(io);

    var output = std.ArrayList(u8){};
    defer output.deinit(allocator);

    try output.appendSlice(allocator, &PNG_SIGNATURE);

    var ihdr: [13]u8 = undefined;
    std.mem.writeInt(u32, ihdr[0..4], width, .big);
    std.mem.writeInt(u32, ihdr[4..8], height, .big);
    ihdr[8] = 8;
    ihdr[9] = 6;
    ihdr[10] = 0;
    ihdr[11] = 0;
    ihdr[12] = 0;
    try writeChunkToList(allocator, &output, "IHDR", &ihdr);
    try writeChunkToList(allocator, &output, "IDAT", compressed);
    try writeChunkToList(allocator, &output, "IEND", &.{});

    try file.writeStreamingAll(io, output.items);
    std.debug.print("PNG exported: {s} ({}x{})\n", .{ path, width, height });
}

pub fn exportBMP(allocator: std.mem.Allocator, path: []const u8, width: u32, height: u32) !void {
    const io = getIo();
    const pixel_count = width * height;
    const pixels = try allocator.alloc(u8, pixel_count * 4);
    defer allocator.free(pixels);

    gl.glReadPixels(0, 0, @intCast(width), @intCast(height), gl.GL_RGBA, gl.GL_UNSIGNED_BYTE, pixels.ptr);

    const row_size = width * 3;
    const row_padding = (4 - (row_size % 4)) % 4;
    const padded_row_size = row_size + row_padding;
    const data_size = padded_row_size * height;

    const cwd = std.Io.Dir.cwd();
    const file = try cwd.createFile(io, path, .{});
    defer file.close(io);

    var output = std.ArrayList(u8){};
    defer output.deinit(allocator);

    try output.appendSlice(allocator, "BM");
    try output.appendSlice(allocator, &std.mem.toBytes(std.mem.nativeToLittle(u32, 54 + @as(u32, @intCast(data_size)))));
    try output.appendSlice(allocator, &std.mem.toBytes(std.mem.nativeToLittle(u16, 0)));
    try output.appendSlice(allocator, &std.mem.toBytes(std.mem.nativeToLittle(u16, 0)));
    try output.appendSlice(allocator, &std.mem.toBytes(std.mem.nativeToLittle(u32, 54)));

    try output.appendSlice(allocator, &std.mem.toBytes(std.mem.nativeToLittle(u32, 40)));
    try output.appendSlice(allocator, &std.mem.toBytes(std.mem.nativeToLittle(i32, @intCast(width))));
    try output.appendSlice(allocator, &std.mem.toBytes(std.mem.nativeToLittle(i32, @intCast(height))));
    try output.appendSlice(allocator, &std.mem.toBytes(std.mem.nativeToLittle(u16, 1)));
    try output.appendSlice(allocator, &std.mem.toBytes(std.mem.nativeToLittle(u16, 24)));
    try output.appendSlice(allocator, &std.mem.toBytes(std.mem.nativeToLittle(u32, 0)));
    try output.appendSlice(allocator, &std.mem.toBytes(std.mem.nativeToLittle(u32, @intCast(data_size))));
    try output.appendSlice(allocator, &std.mem.toBytes(std.mem.nativeToLittle(i32, 2835)));
    try output.appendSlice(allocator, &std.mem.toBytes(std.mem.nativeToLittle(i32, 2835)));
    try output.appendSlice(allocator, &std.mem.toBytes(std.mem.nativeToLittle(u32, 0)));
    try output.appendSlice(allocator, &std.mem.toBytes(std.mem.nativeToLittle(u32, 0)));

    const padding = [_]u8{0} ** 3;
    for (0..height) |yy| {
        for (0..width) |x| {
            const i = (yy * width + x) * 4;
            try output.append(allocator, pixels[i + 2]);
            try output.append(allocator, pixels[i + 1]);
            try output.append(allocator, pixels[i + 0]);
        }
        if (row_padding > 0) {
            try output.appendSlice(allocator, padding[0..row_padding]);
        }
    }

    try file.writeStreamingAll(io, output.items);
    std.debug.print("BMP exported: {s} ({}x{})\n", .{ path, width, height });
}

pub fn exportHDR(allocator: std.mem.Allocator, path: []const u8, width: u32, height: u32) !void {
    const io = getIo();
    const pixel_count = width * height;
    const pixels = try allocator.alloc(f32, pixel_count * 4);
    defer allocator.free(pixels);

    gl.glReadPixels(0, 0, @intCast(width), @intCast(height), gl.GL_RGBA, gl.GL_FLOAT, @ptrCast(pixels.ptr));

    const cwd = std.Io.Dir.cwd();
    const file = try cwd.createFile(io, path, .{});
    defer file.close(io);

    var output = std.ArrayList(u8){};
    defer output.deinit(allocator);

    try output.appendSlice(allocator, "#?RADIANCE\n");
    try output.appendSlice(allocator, "FORMAT=32-bit_rle_rgbe\n\n");

    var header_buf: [64]u8 = undefined;
    const header = std.fmt.bufPrint(&header_buf, "-Y {} +X {}\n", .{ height, width }) catch "-Y 0 +X 0\n";
    try output.appendSlice(allocator, header);

    var y: i32 = @intCast(height - 1);
    while (y >= 0) : (y -= 1) {
        for (0..width) |x| {
            const i = (@as(usize, @intCast(y)) * width + x) * 4;
            const r = pixels[i + 0];
            const g = pixels[i + 1];
            const b = pixels[i + 2];
            const max_val = @max(r, @max(g, b));
            if (max_val < 1e-32) {
                try output.appendSlice(allocator, &[_]u8{ 0, 0, 0, 0 });
            } else {
                const scale = std.math.frexp(max_val).significand * 256.0 / max_val;
                const exp = std.math.frexp(max_val).exponent;
                try output.append(allocator, @intFromFloat(@min(255, r * scale)));
                try output.append(allocator, @intFromFloat(@min(255, g * scale)));
                try output.append(allocator, @intFromFloat(@min(255, b * scale)));
                try output.append(allocator, @intCast(exp + 128));
            }
        }
    }

    try file.writeStreamingAll(io, output.items);
    std.debug.print("HDR exported: {s} ({}x{})\n", .{ path, width, height });
}

const win32 = @cImport({
    @cDefine("WIN32_LEAN_AND_MEAN", "1");
    @cInclude("windows.h");
    @cInclude("commdlg.h");
});

pub fn showSaveDialog(filter: [*:0]const u8, default_ext: [*:0]const u8) ?[260]u8 {
    var filename: [260]u8 = [_]u8{0} ** 260;
    var ofn: win32.OPENFILENAMEA = std.mem.zeroes(win32.OPENFILENAMEA);
    ofn.lStructSize = @sizeOf(win32.OPENFILENAMEA);
    ofn.lpstrFilter = filter;
    ofn.lpstrFile = &filename;
    ofn.nMaxFile = 260;
    ofn.lpstrDefExt = default_ext;
    ofn.Flags = 0x00000002 | 0x00000004;
    if (win32.GetSaveFileNameA(&ofn) != 0) return filename;
    return null;
}

pub fn showOpenDialog(filter: [*:0]const u8) ?[260]u8 {
    var filename: [260]u8 = [_]u8{0} ** 260;
    var ofn: win32.OPENFILENAMEA = std.mem.zeroes(win32.OPENFILENAMEA);
    ofn.lStructSize = @sizeOf(win32.OPENFILENAMEA);
    ofn.lpstrFilter = filter;
    ofn.lpstrFile = &filename;
    ofn.nMaxFile = 260;
    ofn.Flags = 0x00001000 | 0x00000004;
    if (win32.GetOpenFileNameA(&ofn) != 0) return filename;
    return null;
}
