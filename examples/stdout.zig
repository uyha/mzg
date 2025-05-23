pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var buffer: std.ArrayListUnmanaged(u8) = .empty;
    defer buffer.deinit(allocator);

    try mzg.pack(
        Complex{ .real = 42, .img = 24 },
        std.io.getStdOut().writer(),
    );
}

const std = @import("std");
const mzg = @import("mzg");

const Complex = struct {
    real: usize,
    img: usize,
};
