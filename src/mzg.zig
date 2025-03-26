pub const packArray = @import("array.zig").packArray;
pub const packBin = @import("bin.zig").packBin;
pub const packBool = @import("bool.zig").packBool;
pub const packFloat = @import("float.zig").packFloat;
pub const packInt = @import("int.zig").packInt;
pub const packMap = @import("map.zig").packMap;
pub const packNil = @import("nil.zig").packNil;
pub const packStr = @import("str.zig").packStr;

pub const unpackArray = @import("array.zig").unpackArray;
pub const unpackBin = @import("bin.zig").unpackBin;
pub const unpackBool = @import("bool.zig").unpackBool;
pub const unpackFloat = @import("float.zig").unpackFloat;
pub const unpackInt = @import("int.zig").unpackInt;
pub const unpackMap = @import("map.zig").unpackMap;
pub const unpackNil = @import("nil.zig").unpackNil;
pub const unpackStr = @import("str.zig").unpackStr;

const ext = @import("ext.zig");
pub const Ext = ext.Ext;
pub const packExt = ext.packExt;
pub const Timestamp = ext.Timestamp;
pub const packTimestamp = ext.packTimestamp;

pub const format = @import("format.zig");

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
