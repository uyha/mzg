pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var buffer: std.ArrayList(u8) = .empty;
    defer buffer.deinit(allocator);

    try mzg.pack(
        "a string with some characters for demonstration purpose",
        buffer.writer(allocator),
    );

    var string: []const u8 = undefined;
    const size = try mzg.unpack(buffer.items, &string);
    std.debug.print("Consumed {} bytes\n", .{size});
    std.debug.print("string: {s}\n", .{string});
}

const std = @import("std");
const mzg = @import("mzg");
