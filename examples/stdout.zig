pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var buffer: std.ArrayList(u8) = .empty;
    defer buffer.deinit(allocator);

    var outBuffer: [128]u8 = undefined;
    var outWriter = stdout().writer(&outBuffer);
    defer outWriter.end() catch @panic("Failed to write to stdout");

    const writer: *Writer = &outWriter.interface;

    try mzg.pack(Complex{ .real = 42, .img = 24 }, writer);
}

const std = @import("std");
const Writer = std.Io.Writer;
const stdout = std.fs.File.stdout;

const mzg = @import("mzg");

const Complex = struct {
    real: usize,
    img: usize,
};
