comptime {
    for (.{
        @import("family/array.zig"),
        @import("family/bin.zig"),
        @import("family/bool.zig"),
        @import("family/ext.zig"),
        @import("family/float.zig"),
        @import("family/int.zig"),
        @import("family/map.zig"),
        @import("family/nil.zig"),
        @import("family/str.zig"),
        @import("pack.zig"),
    }) |target| {
        @import("std").testing.refAllDeclsRecursive(target);
    }
}
