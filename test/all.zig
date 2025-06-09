comptime {
    const t = @import("std").testing;
    for (.{
        @import("pack.zig"),
        @import("unpack.zig"),
    }) |target| {
        t.refAllDecls(target);
    }
    t.refAllDecls(@import("family/all.zig"));
    t.refAllDecls(@import("adapter/all.zig"));
}

test "pack then unpack" {
    const std = @import("std");
    const expectEqual = std.testing.expectEqual;
    const expectEqualDeep = std.testing.expectEqualDeep;
    const allocator = std.testing.allocator;

    const mzg = @import("mzg");

    var buffer: std.ArrayListUnmanaged(u8) = .empty;
    defer buffer.deinit(allocator);

    {
        defer buffer.clearRetainingCapacity();

        const in: u64 = 0xDEADBEEF;
        var out: u64 = undefined;
        try mzg.pack(in, buffer.writer(allocator));
        try expectEqual(5, mzg.unpack(buffer.items, &out));
        try expectEqualDeep(in, out);
    }

    {
        defer buffer.clearRetainingCapacity();

        const in: struct { a: enum { a, b, c }, b: f32 } = .{ .a = .a, .b = 1.0 };
        var out: @TypeOf(in) = undefined;

        try mzg.pack(in, buffer.writer(allocator));
        try expectEqual(7, mzg.unpack(buffer.items, &out));
        try expectEqualDeep(in, out);
    }

    {
        defer buffer.clearRetainingCapacity();

        const in = mzg.Timestamp.fromSec(std.math.maxInt(u34));
        var out: mzg.Timestamp = undefined;
        try mzg.pack(in, buffer.writer(allocator));
        try expectEqual(10, mzg.unpack(buffer.items, &out));
        try expectEqualDeep(in, out);
    }
}
