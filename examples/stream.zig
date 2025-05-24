pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var buffer: std.ArrayListUnmanaged(u8) = .empty;
    defer buffer.deinit(allocator);

    var in: std.ArrayListUnmanaged(Targets) = .empty;
    defer in.deinit(allocator);
    try in.append(allocator, .{ .position = .init(1000), .velocity = .init(50) });
    try in.append(allocator, .{ .position = .init(2000), .velocity = .init(10) });
    try mzg.pack(adapter.packStream(&in), buffer.writer(allocator));
    try mzg.pack(
        Targets{ .position = .init(3000), .velocity = .init(90) },
        buffer.writer(allocator),
    );

    var targets: std.ArrayListUnmanaged(Targets) = .empty;
    defer targets.deinit(allocator);
    const size = try mzg.unpackAllocate(
        allocator,
        buffer.items,
        adapter.unpackStream(&targets),
    );
    std.debug.print("Consumed {} bytes\n", .{size});
    for (targets.items) |*t| {
        std.debug.print("{}\n", .{t});
    }
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
