pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var buffer: std.ArrayListUnmanaged(u8) = .empty;
    defer buffer.deinit(allocator);

    std.debug.print("Array packing\n", .{});

    try mzg.pack(&[_]Targets{
        .{ .position = .init(1000), .velocity = .init(50) },
        .{ .position = .init(2000), .velocity = .init(10) },
    }, buffer.writer(allocator));

    // Inject stray byte
    try buffer.append(allocator, 1);

    std.debug.print("MessagPack bytes: {X:02}\n", .{buffer.items});

    var targets: std.ArrayListUnmanaged(Targets) = .empty;
    std.debug.print("Consumed {} bytes\n", .{try mzg.unpack(
        buffer.items,
        mzg.array(&targets, allocator),
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
