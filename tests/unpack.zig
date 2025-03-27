const unpack = @import("mzg").unpack;
const UnpackError = @import("mzg").UnpackError;

const std = @import("std");
const expectEqual = std.testing.expectEqual;
const expectEqualDeep = std.testing.expectEqualDeep;
test "unpack void" {
    var buffer: void = {};
    try expectEqual(1, unpack(&[_]u8{0xC0}, &buffer));
    try expectEqual({}, buffer);
}
test "unpack optional" {
    var buffer: ?u8 = undefined;
    try expectEqual(1, unpack(&[_]u8{0xC0}, &buffer));
    try expectEqual(null, buffer);

    try expectEqual(1, unpack(&[_]u8{0x00}, &buffer));
    try expectEqual(0, buffer);
}
test "unpack bool" {
    var buffer: bool = undefined;
    try expectEqual(1, unpack(&[_]u8{0xC2}, &buffer));
    try expectEqual(false, buffer);

    try expectEqual(1, unpack(&[_]u8{0xC3}, &buffer));
    try expectEqual(true, buffer);
}
test "unpack int" {
    var buffer: u8 = undefined;
    try expectEqual(2, unpack(&[_]u8{ 0xCC, 0xFF }, &buffer));
    try expectEqual(0xFF, buffer);

    try expectEqual(3, unpack(&[_]u8{ 0xCD, 0x00, 0xFF }, &buffer));
    try expectEqual(0xFF, buffer);

    try expectEqual(error.ValueInvalid, unpack(&[_]u8{ 0xCD, 0x01, 0xFF }, &buffer));
    try expectEqual(0xFF, buffer);

    try expectEqual(error.BufferUnderRun, unpack(&[_]u8{0xCC}, &buffer));
}
test "unpack float" {
    var float32: f32 = undefined;
    try expectEqual(5, unpack(&[_]u8{ 0xCA, 0x3F, 0x80, 0x00, 0x00 }, &float32));
    try expectEqual(1.0, float32);

    var float64: f64 = undefined;
    try expectEqual(5, unpack(&[_]u8{ 0xCA, 0x3F, 0x80, 0x00, 0x00 }, &float64));
    try expectEqual(1.0, float64);

    try expectEqual(
        9,
        unpack(&[_]u8{ 0xCB, 0x3F, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, &float64),
    );
    try expectEqual(1.0, float64);
}
test "unpack enum" {
    var e: enum(u8) { a, b, longname, c = 0xFF } = undefined;
    try expectEqual(1, unpack(&[_]u8{0x00}, &e));
    try expectEqual(.a, e);
    try expectEqual(error.ValueInvalid, unpack(&[_]u8{0x03}, &e));
    try expectEqual(.a, e);

    try expectEqual(1, unpack(&[_]u8{0x01}, &e));
    try expectEqual(.b, e);

    try expectEqual(2, unpack(&[_]u8{ 0xCC, 0xFF }, &e));
    try expectEqual(.c, e);

    try expectEqual(2, unpack(&[_]u8{ 0xA1, 0x61 }, &e));
    try expectEqual(.a, e);
    try expectEqual(
        9,
        unpack(&[_]u8{ 0xA8, 0x6C, 0x6F, 0x6E, 0x67, 0x6E, 0x61, 0x6D, 0x65 }, &e),
    );
    try expectEqual(.longname, e);

    const C = enum {
        a,
        pub fn mzgUnpack(buffer: []const u8, out: anytype) UnpackError!usize {
            _ = buffer;
            _ = out;

            return 0;
        }
    };
    var c: C = undefined;
    try expectEqual(0, unpack(&[_]u8{}, &c));
}
test "unpack str" {
    var buffer: []const u8 = undefined;
    try expectEqual(2, unpack(&[_]u8{ 0xA1, 0x61 }, &buffer));
    try expectEqualDeep("a", buffer);

    try expectEqual(
        6,
        unpack(&[_]u8{ 0xA5, 0x61, 0x62, 0x63, 0x64, 0x65 }, &buffer),
    );
    try expectEqualDeep("abcde", buffer);

    try expectEqual(
        7,
        unpack(&[_]u8{ 0xC4, 0x05, 0x31, 0x32, 0x33, 0x34, 0x35 }, &buffer),
    );
    try expectEqualDeep("12345", buffer);
}
test "unpack array" {
    var size: usize = undefined;
    try expectEqual(1, unpack(&[_]u8{0x91}, &size));
    try expectEqual(1, size);

    try expectEqual(3, unpack(&[_]u8{ 0xDC, 0xFE, 0xEF }, &size));
    try expectEqual(0xFEEF, size);

    try expectEqual(5, unpack(&[_]u8{ 0xDD, 0xFE, 0xEF, 0xAB, 0xCD }, &size));
    try expectEqual(0xFEEFABCD, size);
}
test "unpack map" {
    var size: usize = undefined;
    try expectEqual(1, unpack(&[_]u8{0x81}, &size));
    try expectEqual(1, size);

    try expectEqual(3, unpack(&[_]u8{ 0xDE, 0xFE, 0xEF }, &size));
    try expectEqual(0xFEEF, size);

    try expectEqual(5, unpack(&[_]u8{ 0xDF, 0xFE, 0xEF, 0xAB, 0xCD }, &size));
    try expectEqual(0xFEEFABCD, size);
}
test "unpack union" {
    var u: union(enum) {
        a: usize,
    } = undefined;
    try expectEqual(3, unpack(&[_]u8{ 0x92, 0x00, 0x01 }, &u));
    try expectEqualDeep(@TypeOf(u){ .a = 1 }, u);

    try expectEqual(4, unpack(&[_]u8{ 0x81, 0xA1, 0x61, 0x02 }, &u));
    try expectEqualDeep(@TypeOf(u){ .a = 2 }, u);
}
test "unpack struct" {
    var t: struct { u32, u32 } = undefined;
    try expectEqual(3, unpack(&[_]u8{ 0x92, 0x00, 0x01 }, &t));
    try expectEqualDeep(.{ 0, 1 }, t);

    var s: struct { a: u32, b: u32 } = undefined;
    try expectEqual(3, unpack(&[_]u8{ 0x92, 0x00, 0x01 }, &s));
    try expectEqualDeep(@TypeOf(s){ .a = 0, .b = 1 }, s);

    try expectEqual(7, unpack(&[_]u8{ 0x82, 0xA1, 0x61, 0x00, 0xA1, 0x62, 0x01 }, &s));
    try expectEqualDeep(@TypeOf(s){ .a = 0, .b = 1 }, s);

    const C = struct {
        a: u32,
        b: ?[]u8,

        pub fn mzgUnpack(buffer: []const u8, out: *@This()) UnpackError!usize {
            out.b = null;
            return @import("mzg").unpackInt(buffer, &out.a);
        }
    };
    var c: C = undefined;
    try expectEqual(1, unpack(&[_]u8{0x01}, &c));
    try expectEqualDeep(C{ .a = 1, .b = null }, c);

    var nest: struct { u32, C } = undefined;
    try expectEqual(3, unpack(&[_]u8{ 0x92, 0x01, 0x01 }, &nest));
    try expectEqualDeep(@TypeOf(nest){ 0x01, C{ .a = 1, .b = null } }, nest);
}
