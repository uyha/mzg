test "packNil" {
    const expect = @import("../utils.zig").expect;

    const packNil = @import("zmgp").packNil;

    try expect(packNil, &[_]u8{0xC0}, {});
}
