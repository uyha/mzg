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
    const allocator = t.allocator;

    var allocWriter: Writer.Allocating = .init(allocator);
    defer allocWriter.deinit();
    const writer: *Writer = &allocWriter.writer;

    var in: std.ArrayList(Targets) = .empty;
    defer in.deinit(allocator);
    try in.append(allocator, .{ .position = .init(1000), .velocity = .init(50) });
    try in.append(allocator, .{ .position = .init(2000), .velocity = .init(10) });
    try mzg.pack(adapter.packStream(&in), writer);

    var out: std.ArrayList(Targets) = .empty;
    defer out.deinit(allocator);
    _ = try mzg.unpackAllocate(
        allocator,
        writer.buffer[0..writer.end],
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
                    .{ std.ArrayList(Targets), adapter.unpackStream },
                },
                buffer,
                out,
            );
        }
    }.f;

    const allocator = t.allocator;

    var allocWriter: Writer.Allocating = .init(allocator);
    defer allocWriter.deinit();
    const writer: *Writer = &allocWriter.writer;

    var in: std.ArrayList(Targets) = .empty;
    defer in.deinit(allocator);
    try in.append(allocator, .{ .position = .init(1000), .velocity = .init(50) });
    try in.append(allocator, .{ .position = .init(2000), .velocity = .init(10) });
    try mzg.pack(adapter.packStream(&in), writer);

    var out: std.ArrayList(Targets) = .empty;
    defer out.deinit(allocator);
    _ = try unpack(allocator, writer.buffer[0..writer.end], &out);

    try t.expectEqualDeep(in, out);
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const t = std.testing;
const Writer = std.Io.Writer;

const mzg = @import("mzg");
const adapter = mzg.adapter;
