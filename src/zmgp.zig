pub const packNil = @import("family/nil.zig").packNil;
pub const packBool = @import("family/bool.zig").packBool;

const int = @import("family/int.zig");
pub const packInt = int.packInt;
pub const packIntWithEndian = int.packIntWithEndian;

const float = @import("family/float.zig");
pub const packFloat = float.packFloat;
pub const packFloatWithEndian = float.packFloatWithEndian;

pub const packStr = @import("family/str.zig").packStr;
pub const packBin = @import("family/bin.zig").packBin;
pub const packArray = @import("family/array.zig").packArray;
pub const packMap = @import("family/map.zig").packMap;

const ext = @import("family/ext.zig");
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
