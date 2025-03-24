const utils = @import("utils.zig");
const expect = utils.expect;
const NativeUsize = utils.NativeUsize;
const writeWithEndian = utils.writeWithEndian;

const nil = @import("nil.zig");
pub const packNil = nil.packNil;

const @"bool" = @import("bool.zig");
pub const packBool = @"bool".packBool;

const int = @import("int.zig");
pub const packInt = int.packInt;

const float = @import("float.zig");
pub const packFloat = float.packFloat;

const str = @import("str.zig");
pub const packStr = str.packStr;

const bin = @import("bin.zig");
pub const packBin = bin.packBin;

const array = @import("array.zig");
pub const packArray = array.packArray;

const map = @import("map.zig");
pub const packMap = map.packMap;

comptime {
    for (&[_]type{ nil, @"bool", int, float, str, bin, array, map }) |T| {
        @import("std").testing.refAllDeclsRecursive(T);
    }
}
