pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var buffer: std.ArrayListUnmanaged(u8) = .empty;
    defer buffer.deinit(allocator);

    try mzg.pack([_]Targets{
        .{ .position = .init(1000), .velocity = .init(50) },
        .{ .position = .init(2000), .velocity = .init(10) },
    }, buffer.writer(allocator));

    std.debug.print("MessagPack bytes: {X:02}\n", .{buffer.items});

    var targets: std.ArrayListUnmanaged(Targets) = .empty;
    var len: usize = 0;
    var size: usize = try mzg.unpack(buffer.items, &len);

    for (0..len) |_| {
        size += mzg.unpack(
            buffer.items[size..],
            try targets.addOne(allocator),
        ) catch {
            // Remove unpopulated item
            _ = targets.pop();
            break;
        };
    }
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
