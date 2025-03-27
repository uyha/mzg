const std = @import("std");
const mzg = @import("mzg");
const PackOptions = mzg.PackOptions;

fn expect(comptime options: PackOptions, expected: anytype, input: anytype) !void {
    var buffer: std.ArrayListUnmanaged(u8) = .empty;
    defer buffer.deinit(std.testing.allocator);

    try mzg.packWithOptions(
        input,
        options,
        buffer.writer(std.testing.allocator),
    );

    try std.testing.expectEqualDeep(expected, buffer.items);
}

test "pack nil" {
    try expect(.default, &[_]u8{0xC0}, null);
    try expect(.default, &[_]u8{0xC0}, {});
}
test "pack bool" {
    try expect(.default, &[_]u8{0xC2}, false);
    try expect(.default, &[_]u8{0xC3}, true);
}
test "pack int" {
    try expect(.default, &[_]u8{0x00}, 0);
    try expect(
        .default,
        &[_]u8{ 0xD3, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },
        std.math.minInt(i64),
    );
}
test "pack float" {
    try expect(.default, &[_]u8{ 0xCA, 0x3F, 0x80, 0x00, 0x00 }, @as(f16, 1.0));
    try expect(.default, &[_]u8{ 0xCA, 0x3F, 0x80, 0x00, 0x00 }, @as(f32, 1.0));
}
test "pack optional" {
    try expect(.default, &[_]u8{0x01}, @as(?u8, 1));
    try expect(.default, &[_]u8{0xC0}, @as(?u8, null));
}
test "pack enum" {
    const E = enum { @"1", a, b, c };
    try expect(.default, &[_]u8{0x00}, E.@"1");
    try expect(.stringly, &[_]u8{ 0xA1, 0x31 }, E.@"1");

    try expect(.default, &[_]u8{0x03}, E.c);
    try expect(.stringly, &[_]u8{ 0xA1, 0x63 }, E.c);

    const C = enum {
        a,
        pub fn mzgPack(_: @This(), writer: anytype) !void {
            try mzg.packInt(1, writer);
        }
    };
    try expect(.default, &[_]u8{0x01}, C.a);
    try expect(.stringly, &[_]u8{0x01}, C.a);
}
test "pack enum literal" {
    try expect(.stringly, &[_]u8{ 0xA1, 0x7A }, .z);
}
test "pack tagged union" {
    const U = union(enum) { a: u8, b: ?u16, c: bool };
    try expect(.default, &[_]u8{ 0x92, 0x00, 0x01 }, U{ .a = 1 });
    try expect(.stringly, &[_]u8{ 0x92, 0xA1, 0x61, 0x01 }, U{ .a = 1 });

    try expect(.default, &[_]u8{ 0x92, 0x02, 0xC3 }, U{ .c = true });
    try expect(.stringly, &[_]u8{ 0x92, 0xA1, 0x63, 0xC3 }, U{ .c = true });

    const C = union(enum) {
        a: u8,
        b: ?u16,
        c: bool,
        pub fn mzgPack(_: @This(), writer: anytype) !void {
            try mzg.packInt(1, writer);
        }
    };
    try expect(.default, &[_]u8{0x01}, C{ .a = 1 });
    try expect(.stringly, &[_]u8{0x01}, C{ .a = 1 });
}
test "pack tuple" {
    try expect(.default, &[_]u8{ 0x92, 0x01, 0xC0 }, .{ 1, null });
    try expect(.stringly, &[_]u8{ 0x92, 0x01, 0xA1, 0x63 }, .{ 1, .c });
}
test "pack struct" {
    const S = struct {
        a: u16,
        b: ?f32,
    };
    try expect(
        .default,
        &[_]u8{ 0x92, 0x01, 0xCA, 0x3F, 0x80, 0x00, 0x00 },
        S{ .a = 1, .b = 1.0 },
    );
    try expect(
        .stringly,
        &[_]u8{ 0x82, 0xA1, 0x61, 0x01, 0xA1, 0x62, 0xCA, 0x3F, 0x80, 0x00, 0x00 },
        S{ .a = 1, .b = 1.0 },
    );
    try expect(.stringly, &[_]u8{ 0x81, 0xA1, 0x61, 0x01 }, S{ .a = 1, .b = null });
    try expect(
        .full_stringly,
        &[_]u8{ 0x82, 0xA1, 0x61, 0x01, 0xA1, 0x62, 0xC0 },
        S{ .a = 1, .b = null },
    );

    const C = struct {
        a: u16,
        b: ?f32,

        pub fn mzgPack(_: @This(), writer: anytype) !void {
            try mzg.packInt(1, writer);
        }
    };
    try expect(.default, &[_]u8{0x01}, C{ .a = 1, .b = 1.0 });
    try expect(.stringly, &[_]u8{0x01}, C{ .a = 1, .b = 1.0 });
    try expect(.stringly, &[_]u8{0x01}, C{ .a = 1, .b = null });
    try expect(.full_stringly, &[_]u8{0x01}, C{ .a = 1, .b = null });

    const p: packed struct { a: u4, b: u4 } = .{ .a = 1, .b = 2 };
    switch (@import("builtin").target.cpu.arch.endian()) {
        .little => {
            try expect(.default, &[_]u8{0x21}, p);
        },
        .big => {
            try expect(.default, &[_]u8{0x12}, p);
        },
    }
}
test "pack []u8 like" {
    const content = [_]u8{1};
    try expect(.default, &[_]u8{ 0xA1, 0x01 }, content);
    try expect(.default, &[_]u8{ 0xA1, 0x31 }, "1");

    try expect(.stringly, &[_]u8{ 0xA1, 0x01 }, content);
    try expect(.stringly, &[_]u8{ 0xA1, 0x31 }, "1");

    try expect(.full_stringly, &[_]u8{ 0xA1, 0x01 }, content);
    try expect(.full_stringly, &[_]u8{ 0xA1, 0x31 }, "1");
}
test "pack pointer and array like" {
    const array = [_]u32{ 1, 2 };
    try expect(.default, &[_]u8{ 0x92, 0x01, 0x02 }, array);
    try expect(.default, &[_]u8{ 0x92, 0x01, 0x02 }, &array);
    try expect(.stringly, &[_]u8{ 0x92, 0x01, 0x02 }, array);
    try expect(.stringly, &[_]u8{ 0x92, 0x01, 0x02 }, &array);

    const vec: @Vector(2, u32) = @splat(4);
    try expect(.default, &[_]u8{ 0x92, 0x04, 0x04 }, vec);
    try expect(.default, &[_]u8{ 0x92, 0x04, 0x04 }, &vec);
    try expect(.stringly, &[_]u8{ 0x92, 0x04, 0x04 }, vec);
    try expect(.stringly, &[_]u8{ 0x92, 0x04, 0x04 }, &vec);

    const value: u32 = 1;
    const pointer = &value;
    try expect(.default, &[_]u8{0x01}, pointer);

    const sen_slice: [*:2]const u32 = array[0..1 :2];
    try expect(.default, &[_]u8{ 0x91, 0x01 }, sen_slice);
}
test "pack Timestamp" {
    const ts: mzg.Timestamp = .fromMilli(1_500);
    try expect(
        .default,
        &[_]u8{ 0xD7, 0xFF, 0x77, 0x35, 0x94, 0x00, 0x00, 0x00, 0x00, 0x01 },
        ts,
    );
    try expect(
        .stringly,
        &[_]u8{ 0xD7, 0xFF, 0x77, 0x35, 0x94, 0x00, 0x00, 0x00, 0x00, 0x01 },
        ts,
    );
}
