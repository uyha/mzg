test "packBool" {
    const packBool = @import("zmgp").packBool;

    const expect = @import("utils.zig").expect;
    try expect(packBool, &[_]u8{0xC2}, false);
    try expect(packBool, &[_]u8{0xC3}, true);
}
