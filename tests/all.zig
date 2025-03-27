comptime {
    for (.{
        @import("array.zig"),
        @import("bin.zig"),
        @import("bool.zig"),
        @import("ext.zig"),
        @import("float.zig"),
        @import("int.zig"),
        @import("map.zig"),
        @import("nil.zig"),
        @import("str.zig"),
        @import("pack.zig"),
        @import("unpack.zig"),
    }) |target| {
        @import("std").testing.refAllDeclsRecursive(target);
    }
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
}
