comptime {
    for (.{
        @import("array.zig"),
        @import("bin.zig"),
        @import("bool.zig"),
        @import("ext.zig"),
        @import("float.zig"),
        @import("int.zig"),
        @import("map.zig"),
        @import("nil.zig"),
        @import("str.zig"),
        @import("pack.zig"),
        @import("unpack.zig"),
    }) |target| {
        @import("std").testing.refAllDeclsRecursive(target);
    }
}
