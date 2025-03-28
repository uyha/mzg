pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var buffer: std.ArrayListUnmanaged(u8) = .empty;
    defer buffer.deinit(allocator);

    std.debug.print("Stream packing\n", .{});

    var in: std.ArrayListUnmanaged(Targets) = .empty;
    defer in.deinit(allocator);
    try in.append(allocator, .{ .position = .init(1000), .velocity = .init(50) });
    try in.append(allocator, .{ .position = .init(2000), .velocity = .init(10) });
    try mzg.pack(adapter.packStream(&in), buffer.writer(allocator));

    std.debug.print("MessagPack bytes: {X:02}\n", .{buffer.items});

    var targets: std.ArrayListUnmanaged(Targets) = .empty;
    std.debug.print("Consumed {} bytes\n", .{try mzg.unpack(
        buffer.items,
        adapter.unpackStream(&targets, allocator),
    )});
    std.debug.print("Length: {}\n", .{targets.items.len});
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
