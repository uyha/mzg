const zmgp = @import("zmgp.zig");
const std = @import("std");

pub const Behavior = struct {
    const Self = @This();

    /// This field decides if a byte slice like value (`[N]u8`, `[]u8`, etc.) should be
    /// packed as a `str` or a `bin`.
    byte_slice: enum { str, bin } = .bin,
    /// This field decides if an enum should be packed using its name or value. If the
    /// enum is packed using its name, it cannot be a non-exhaustive enum. However, this
    /// does not impact how a tagged union is packed.
    @"enum": enum { name, value } = .value,
    /// This field decides if an error set is packed using its name or value.
    @"error": enum { name, value } = .value,
    /// This field decides if a struct is packed as an array or a map. A tuple is always
    /// packed as an array.
    @"struct": enum { array, map } = .array,
    /// This field decides if a field being null in a struct is skipped or not. It only
    /// has an effect when `@"struct"` is `.map` and it does not affect how a tuple is
    /// packed.
    skip_null: bool = true,

    pub const default: Self = .{};
    pub const stringly: Self = .{
        .@"enum" = .name,
        .@"error" = .name,
        .@"struct" = .map,
    };
    pub const full_stringly: Self = .{
        .@"enum" = .name,
        .@"error" = .name,
        .@"struct" = .map,
        .skip_null = false,
    };
};
pub fn Packer(comptime behavior: Behavior, comptime Writer: type) type {
    return struct {
        const Self = @This();

        writer: Writer,

        pub fn init(writer: Writer) Self {
            return .{ .writer = writer };
        }

        /// Pack the given Zig value as MessagePack
        ///
        /// Supported types:
        /// * Zig `null` and `void` -> `nil`.
        /// * Zig `bool` -> `bool`.
        /// * Zig `u8`, `i16`, `comptime_int`, etc. -> `int`.
        /// * Zig `f16`, `f32`, `f64`, `comptime_float`, etc. -> `float`.
        ///     * `f16` is converted to `f32` and then gets packed as `f32`.
        ///     * `comptime_float` is converted to `f64` and then gets packed as `f64`.
        /// * Zig optionals -> `nil` if it is null, otherwise, packed as the
        ///   corresponding `child` type.
        /// * Zig enums ->
        ///     * If the enum has the method
        ///       `pub fn zmgpPack(self: *@This(), packer: anytype) !void`, it is called
        ///       with `packer` being a pointer to a constant packer.
        ///     * Othwerwise, if `behavior.@"enum"` is `.name`, then the name of the enum
        ///       is packed as a str, otherwise, its value is packed an int.
        ///       Non-exhaustive enums cannot be used with `behavior.@"enum"` being
        ///       `.name`.
        /// * Zig untyped enum literal -> Can only be packed if `behavior.@"enum"` is
        ///   `.name`. The name of the enum is packed as a str.
        /// * Zig tagged unions ->
        ///     * If the union has the method
        ///       `pub fn zmgpPack(self: *@This(), packer: anytype) !void`, it is called
        ///       with `packer` being a pointer to a constant packer.
        ///     * Otherwise, it is packed as an `array` with 2 elements, the first being
        ///       the tag enum, and the second being the actual value of the union. How
        ///       the tag enum is packed is decided by `behavior.@"enum"`. Untagged
        ///       unions cannot be packed.
        /// * Zig structs ->
        ///     * If the struct has the method
        ///       `pub fn zmgpPack(self: *@This(), packer: anytype) !void`, it is called
        ///       with `packer` being a pointer to a constant packer.
        ///     * Otherwise, if it is
        ///         * a tuple, all the fields are packed in an `array` in the order they
        ///           are declared.
        ///         * a normal struct, if `behavior.@"struct"`
        ///             * is `.array`, the fields are packed in an `array` in the other
        ///               they are declared.
        ///             * is `.map`, the fields are packed in a `map`, with the keys
        ///               being their names and the values being their values. In this
        ///               case, if `behavior.skip_null` is `true`, null fields will be
        ///               skipped.
        /// * Zig error -> `str` if `behavior.@"error"` is `.name`, otherwise, `int`.
        /// * Zig slices, arrays, sentinel-terminated pointers, and @Vector of `u8` ->
        ///   `str` if `behavior.byte_slice` is `.str`, otherwise, `bin`.
        /// * Zig slices, arrays, sentinel-terminated pointers of other types -> `array`
        ///   of the elements.
        /// * Zig `*T` -> packed as `T`
        pub fn pack(self: *const Self, value: anytype) zmgp.PackError(Writer)!void {
            const Value = @TypeOf(value);
            switch (@typeInfo(Value)) {
                .null, .void => try zmgp.packNil(self.writer),
                .bool => try zmgp.packBool(self.writer, value),
                .comptime_int, .int => try zmgp.packInt(self.writer, value),
                .comptime_float, .float => try zmgp.packFloat(self.writer, value),
                .optional => {
                    if (value) |payload| {
                        return self.pack(payload);
                    } else {
                        return zmgp.packNil(self.writer);
                    }
                },
                .@"enum" => |info| {
                    if (std.meta.hasFn(Value, "zmgpPack")) {
                        return value.zmgpPack(self);
                    }
                    switch (behavior.@"enum") {
                        .value => return zmgp.packInt(self.writer, @intFromEnum(value)),
                        .name => {
                            if (!info.is_exhaustive) {
                                @compileError("Cannot pack non-exhaustive enum using its name");
                            }
                            return zmgp.packStr(self.writer, @tagName(value));
                        },
                    }
                },
                .enum_literal => {
                    if (behavior.@"enum" == .value) {
                        @compileError("Cannot pack enum literal when behavior requries the value of the enum is packed");
                    }

                    return zmgp.packStr(self.writer, @tagName(value));
                },
                .@"union" => |info| {
                    if (std.meta.hasFn(Value, "zmgpPack")) {
                        return value.zmgpPack(self);
                    }

                    if (info.tag_type != null) {
                        switch (value) {
                            inline else => |payload, tag| return self.pack(
                                .{ tag, payload },
                            ),
                        }
                    } else {
                        @compileError("Cannot pack untagged union '" ++ @typeName(Value) ++ "'");
                    }
                },
                .@"struct" => |info| {
                    if (std.meta.hasFn(Value, "msgpPack")) {
                        return value.msgpPack(self);
                    }
                    if (info.is_tuple) {
                        try zmgp.packArray(self.writer, info.fields.len);
                        inline for (info.fields) |field| {
                            try self.pack(@field(value, field.name));
                        }
                        return;
                    }

                    switch (behavior.@"struct") {
                        .array => {
                            try zmgp.packArray(self.writer, info.fields.len);
                            inline for (info.fields) |field| {
                                try self.pack(@field(value, field.name));
                            }
                        },
                        .map => {
                            if (behavior.skip_null) {
                                var non_null_len: usize = 0;
                                inline for (info.fields) |field| {
                                    if (@typeInfo(field.type) == .optional) {
                                        if (@field(value, field.name) != null) {
                                            non_null_len += 1;
                                        }
                                    } else {
                                        non_null_len += 1;
                                    }
                                }

                                try zmgp.packMap(self.writer, non_null_len);
                                inline for (info.fields) |field| {
                                    if (@typeInfo(field.type) == .optional) {
                                        if (@field(value, field.name) != null) {
                                            try zmgp.packStr(self.writer, field.name);
                                            try self.pack(@field(value, field.name));
                                        }
                                    } else {
                                        try zmgp.packStr(self.writer, field.name);
                                        try self.pack(@field(value, field.name));
                                    }
                                }
                            } else {
                                try zmgp.packMap(self.writer, info.fields.len);
                                inline for (info.fields) |field| {
                                    try zmgp.packStr(self.writer, field.name);
                                    try self.pack(@field(value, field.name));
                                }
                            }
                        },
                    }
                },
                .error_set => {
                    return switch (behavior.@"error") {
                        .name => zmgp.packStr(self.writer, @errorName(value)),
                        .value => self.pack(@intFromError(value)),
                    };
                },
                .pointer => |ptr| switch (ptr.size) {
                    .one => switch (@typeInfo(ptr.child)) {
                        .array => {
                            const Slice = []const std.meta.Elem(ptr.child);
                            return self.pack(@as(Slice, value));
                        },
                        else => return self.pack(value.*),
                    },
                    .many, .slice => {
                        if (ptr.size == .many and ptr.sentinel == null) {
                            @compileError("Cannot pack '" ++ @typeName(Value) ++ "' without sentinel");
                        }

                        const slice = if (ptr.size == .many) std.mem.span(value) else value;

                        if (ptr.child == u8) {
                            return switch (behavior.byte_slice) {
                                .str => zmgp.packStr(self.writer, slice),
                                .bin => zmgp.packBin(self.writer, slice),
                            };
                        }

                        try zmgp.packArray(self.writer, slice.len);
                        for (slice) |elem| {
                            try self.pack(elem);
                        }
                        return;
                    },
                    else => @compileError("Cannot pack '" ++ @typeName(Value) ++ "'"),
                },
                .array => return self.pack(&value),
                .vector => |vec| {
                    const array: [vec.len]vec.child = value;
                    return self.pack(&array);
                },

                else => @compileError("'" ++ @typeName(Value) ++ "' is not supported"),
            }
        }
    };
}
