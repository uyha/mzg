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
    const t = @import("std").testing;

    const expectEqual = std.testing.expectEqual;
    const expectEqualDeep = std.testing.expectEqualDeep;

    const mzg = @import("mzg");

    var allocWriter: Writer.Allocating = .init(t.allocator);
    defer allocWriter.deinit();

    const writer: *Writer = &allocWriter.writer;

    {
        defer _ = writer.consumeAll();

        const in: u64 = 0xDEADBEEF;
        var out: u64 = undefined;
        try mzg.pack(in, writer);
        try expectEqual(5, mzg.unpack(writer.buffer[0..writer.end], &out));
        try expectEqualDeep(in, out);
    }

    {
        defer _ = writer.consumeAll();

        const in: struct { a: enum { a, b, c }, b: f32 } = .{ .a = .a, .b = 1.0 };
        var out: @TypeOf(in) = undefined;

        try mzg.pack(in, writer);
        try expectEqual(7, mzg.unpack(writer.buffer[0..writer.end], &out));
        try expectEqualDeep(in, out);
    }

    {
        defer _ = writer.consumeAll();

        const in = mzg.Timestamp.fromSec(std.math.maxInt(u34));
        var out: mzg.Timestamp = undefined;
        try mzg.pack(in, writer);
        try expectEqual(10, mzg.unpack(writer.buffer[0..writer.end], &out));
        try expectEqualDeep(in, out);
    }
}

const std = @import("std");
const Writer = std.Io.Writer;
