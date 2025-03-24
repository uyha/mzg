test "packBool" {
    const packBool = @import("zmgp").packBool;

    const expect = @import("utils.zig").expect;
    try expect(packBool, false, &[_]u8{0xC2});
    try expect(packBool, true, &[_]u8{0xC3});
}
