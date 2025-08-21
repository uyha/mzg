pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var buffer: std.ArrayList(u8) = .empty;
    defer buffer.deinit(allocator);

    try mzg.pack(
        Targets{ .position = .init(2000), .velocity = .init(10) },
        buffer.writer(allocator),
    );

    var targets: Targets = undefined;
    const size = try mzg.unpack(buffer.items, &targets);

    std.debug.print("Consumed {} bytes\n", .{size});
    std.debug.print("Targets: {}\n", .{targets});
}

const Position = enum(i32) {
    _,
    pub fn init(raw: std.meta.Tag(@This())) @This() {
        return @enumFromInt(raw);
    }
};
const Velocity = enum(i32) {
    _,
    pub fn init(raw: std.meta.Tag(@This())) @This() {
        return @enumFromInt(raw);
    }
};
const Targets = struct {
    position: Position,
    velocity: Velocity,
};

const std = @import("std");
const mzg = @import("mzg");
const adapter = mzg.adapter;
