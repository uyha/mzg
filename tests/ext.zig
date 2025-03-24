test "packExt" {
    const expect = @import("utils.zig").expect;

    const maxInt = @import("std").math.maxInt;

    const zmgp = @import("zmgp");
    const Ext = zmgp.Ext;
    const packExt = @import("zmgp").packExt;

    try expect(packExt, Ext.init(1, 1), &[_]u8{ 0xD4, 0x01 });
    try expect(packExt, Ext.init(1, 2), &[_]u8{ 0xD5, 0x01 });
    try expect(packExt, Ext.init(1, 4), &[_]u8{ 0xD6, 0x01 });
    try expect(packExt, Ext.init(1, 8), &[_]u8{ 0xD7, 0x01 });
    try expect(packExt, Ext.init(1, 16), &[_]u8{ 0xD8, 0x01 });
    try expect(packExt, Ext.init(1, 0), &[_]u8{ 0xC7, 0x00, 0x01 });
    try expect(packExt, Ext.init(1, 3), &[_]u8{ 0xC7, 0x03, 0x01 });
    try expect(packExt, Ext.init(1, 5), &[_]u8{ 0xC7, 0x05, 0x01 });
    try expect(packExt, Ext.init(1, maxInt(u8)), &[_]u8{ 0xC7, 0xFF, 0x01 });
    try expect(
        packExt,
        Ext.init(1, maxInt(u16) - 1),
        &[_]u8{ 0xC8, 0xFF, 0xFE, 0x01 },
    );
    try expect(
        packExt,
        Ext.init(1, maxInt(u32) - 1),
        &[_]u8{ 0xC9, 0xFF, 0xFF, 0xFF, 0xFE, 0x01 },
    );
}

test "Timestamp" {
    const std = @import("std");
    const expectEqual = std.testing.expectEqual;

    const zmgp = @import("zmgp");
    const Timestamp = zmgp.Timestamp;

    inline for (.{
        .{ .timestamp = Timestamp.fromSec(1), .sec = 1, .nano = 0 },
        .{ .timestamp = Timestamp.fromSec(-1), .sec = -1, .nano = 0 },
        .{ .timestamp = Timestamp.fromMilli(1), .sec = 0, .nano = 1_000_000 },
        .{ .timestamp = Timestamp.fromMilli(-1), .sec = -1, .nano = 999_000_000 },
        .{ .timestamp = Timestamp.fromMicro(1), .sec = 0, .nano = 1_000 },
        .{ .timestamp = Timestamp.fromMicro(-1), .sec = -1, .nano = 999_999_000 },
        .{ .timestamp = Timestamp.fromNano(1), .sec = 0, .nano = 1 },
        .{ .timestamp = Timestamp.fromNano(-1), .sec = -1, .nano = 999_999_999 },
    }) |spec| {
        try expectEqual(spec.sec, spec.timestamp.sec);
        try expectEqual(spec.nano, spec.timestamp.nano);
    }
}

test "packTimestamp" {
    const expect = @import("utils.zig").expect;

    const maxInt = @import("std").math.maxInt;

    const zmgp = @import("zmgp");
    const Timestamp = zmgp.Timestamp;
    const packTimestamp = zmgp.packTimestamp;

    try expect(
        packTimestamp,
        Timestamp{ .sec = 0, .nano = 1_000_000_000 },
        error.InvalidTimestamp,
    );
    try expect(
        packTimestamp,
        Timestamp.fromSec(1),
        &[_]u8{ 0xD6, 0xFF, 0x00, 0x00, 0x00, 0x01 },
    );
    try expect(
        packTimestamp,
        Timestamp.fromSec(maxInt(u32)),
        &[_]u8{ 0xD6, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF },
    );
    try expect(
        packTimestamp,
        Timestamp.fromSec(maxInt(u34)),
        &[_]u8{ 0xD7, 0xFF, 0x00, 0x00, 0x00, 0x03, 0xFF, 0xFF, 0xFF, 0xFF },
    );
    try expect(
        packTimestamp,
        Timestamp{ .sec = 9, .nano = 999_999_999 },
        &[_]u8{ 0xD7, 0xFF, 0xEE, 0x6B, 0x27, 0xFC, 0x00, 0x00, 0x00, 0x09 },
    );
    try expect(
        packTimestamp,
        Timestamp{ .sec = maxInt(u34), .nano = 999_999_999 },
        &[_]u8{ 0xD7, 0xFF, 0xEE, 0x6B, 0x27, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF },
    );
    try expect(
        packTimestamp,
        Timestamp{ .sec = maxInt(u34) + 1, .nano = 999_999_999 },
        &[_]u8{ 0xC7, 0x0C, 0xFF, 0x3B, 0x9A, 0xC9, 0xFF, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00 },
    );
    try expect(
        packTimestamp,
        Timestamp{ .sec = maxInt(i64), .nano = 999_999_999 },
        &[_]u8{ 0xC7, 0x0C, 0xFF, 0x3B, 0x9A, 0xC9, 0xFF, 0x7F, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF },
    );
}
