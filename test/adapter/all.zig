comptime {
    const t = @import("std").testing;
    t.refAllDecls(@import("array.zig"));
    t.refAllDecls(@import("map.zig"));
    t.refAllDecls(@import("stream.zig"));
}
