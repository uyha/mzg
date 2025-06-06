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

test "pack and unpack with stream adapter" {
    const allocator = std.heap.page_allocator;
    var buffer: std.ArrayListUnmanaged(u8) = .empty;
    defer buffer.deinit(allocator);

    var in: std.ArrayListUnmanaged(Targets) = .empty;
    defer in.deinit(allocator);
    try in.append(allocator, .{ .position = .init(1000), .velocity = .init(50) });
    try in.append(allocator, .{ .position = .init(2000), .velocity = .init(10) });
    try mzg.pack(adapter.packStream(&in), buffer.writer(allocator));

    var out: std.ArrayListUnmanaged(Targets) = .empty;
    defer out.deinit(allocator);
    _ = try mzg.unpackAllocate(
        allocator,
        buffer.items,
        adapter.unpackStream(&out),
    );

    try t.expectEqualDeep(in, out);
}

test "pack and unpack with adaptor map" {
    const unpack = struct {
        fn f(
            allocator: Allocator,
            buffer: []const u8,
            out: anytype,
        ) mzg.UnpackAllocateError!usize {
            return mzg.unpackAdaptedAllocate(
                allocator,
                .{
                    .{ std.ArrayListUnmanaged(Targets), adapter.unpackStream },
                },
                buffer,
                out,
            );
        }
    }.f;

    const allocator = std.heap.page_allocator;
    var buffer: std.ArrayListUnmanaged(u8) = .empty;
    defer buffer.deinit(allocator);

    var in: std.ArrayListUnmanaged(Targets) = .empty;
    defer in.deinit(allocator);
    try in.append(allocator, .{ .position = .init(1000), .velocity = .init(50) });
    try in.append(allocator, .{ .position = .init(2000), .velocity = .init(10) });
    try mzg.pack(adapter.packStream(&in), buffer.writer(allocator));

    var out: std.ArrayListUnmanaged(Targets) = .empty;
    defer out.deinit(allocator);
    _ = try unpack(allocator, buffer.items, &out);

    try t.expectEqualDeep(in, out);
}

const std = @import("std");
const Allocator = std.mem.Allocator;

const t = std.testing;
const mzg = @import("mzg");
const adapter = mzg.adapter;
