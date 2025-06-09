comptime {
    const t = @import("std").testing;

    t.refAllDecls(@import("array.zig"));
    t.refAllDecls(@import("bin.zig"));
    t.refAllDecls(@import("bool.zig"));
    t.refAllDecls(@import("ext.zig"));
    t.refAllDecls(@import("float.zig"));
    t.refAllDecls(@import("int.zig"));
    t.refAllDecls(@import("map.zig"));
    t.refAllDecls(@import("nil.zig"));
    t.refAllDecls(@import("str.zig"));
}
