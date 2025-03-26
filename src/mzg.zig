pub const packNil = @import("nil.zig").packNil;
pub const packBool = @import("bool.zig").packBool;

const int = @import("int.zig");
pub const packInt = int.packInt;
pub const packIntWithEndian = int.packIntWithEndian;

const float = @import("float.zig");
pub const packFloat = float.packFloat;
pub const packFloatWithEndian = float.packFloatWithEndian;

pub const packStr = @import("str.zig").packStr;
pub const packBin = @import("bin.zig").packBin;
pub const packArray = @import("array.zig").packArray;
pub const packMap = @import("map.zig").packMap;

const ext = @import("ext.zig");
pub const Ext = ext.Ext;
pub const packExt = ext.packExt;
pub const Timestamp = ext.Timestamp;
pub const packTimestamp = ext.packTimestamp;

pub const PackError = @import("error.zig").PackError;

const pack = @import("pack.zig");
const Packer = pack.Packer;
pub const PackBehavior = pack.Behavior;
pub fn packer(writer: anytype) Packer(.default, @TypeOf(writer)) {
    return .init(writer);
}
pub fn packerWithBehavior(
    comptime behavior: PackBehavior,
    writer: anytype,
) Packer(behavior, @TypeOf(writer)) {
    return .init(writer);
}

pub const UnpackError = @import("error.zig").UnpackError;
pub const unpack = @import("unpack.zig");
