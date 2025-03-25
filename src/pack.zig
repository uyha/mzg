const mzg = @import("mzg.zig");
const std = @import("std");

pub const Behavior = struct {
    const Self = @This();

    /// This field decides if a byte slice like value (`[N]u8`, `[]u8`, etc.) should be
    /// packed as a `str` or a `bin`.
    byte_slice: enum { str, bin } = .bin,
    /// This field decides if an enum / tagged union should be packed using its name or
    /// value. If the enum is packed using its name, it cannot be a non-exhaustive enum.
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

    /// Pack everything as small as possible.
    pub const default: Self = .{};
    /// Pack enums and errors as strings. Pack structs as maps with field names being the
    /// keys, and null fields are skipped.
    pub const stringly: Self = .{
        .byte_slice = .str,
        .@"enum" = .name,
        .@"error" = .name,
        .@"struct" = .map,
    };
    /// Similar to `.stringly` but null fields in structs are not skipped.
    pub const full_stringly: Self = .{
        .byte_slice = .str,
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
        /// * Zig `u8`, `i16`, `comptime_int`, etc. -> `int`. The packing uses the least
        ///   amount of bytes based on the value.
        /// * Zig `f16`, `f32`, `f64`, `comptime_float`, etc. -> `float`.
        ///     * `f16` is converted to `f32` and then gets packed as `f32`.
        ///     * `comptime_float` is converted to `f64` and then gets packed as `f64`.
        /// * Zig optionals -> `nil` if it is null, otherwise, packed as the
        ///   corresponding `child` type.
        /// * Zig enums ->
        ///     * If the enum has the method
        ///       `pub fn mzgPack(self: *@This(), packer: anytype) !void`, it is called
        ///       with `packer` being a pointer to a constant packer.
        ///     * Othwerwise, if `behavior.@"enum"` is `.name`, then the name of the enum
        ///       is packed as a str, otherwise, its value is packed an int.
        ///       Non-exhaustive enums cannot be used with `behavior.@"enum"` being
        ///       `.name`.
        /// * Zig untyped enum literal -> Can only be packed if `behavior.@"enum"` is
        ///   `.name`. The name of the enum is packed as a str.
        /// * Zig tagged unions ->
        ///     * If the union has the method
        ///       `pub fn mzgPack(self: *@This(), packer: anytype) !void`, it is called
        ///       with `packer` being a pointer to a constant packer.
        ///     * Otherwise, it is packed as an `array` with 2 elements, the first being
        ///       the tag enum, and the second being the actual value of the union. How
        ///       the tag enum is packed is decided by `behavior.@"enum"`. Untagged
        ///       unions cannot be packed.
        /// * Zig structs ->
        ///     * If the struct has the method
        ///       `pub fn mzgPack(self: *@This(), packer: anytype) !void`, it is called
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
        pub fn pack(self: *const Self, value: anytype) mzg.PackError(Writer)!void {
            const Value = @TypeOf(value);
            switch (@typeInfo(Value)) {
                .null, .void => try mzg.packNil(self.writer),
                .bool => try mzg.packBool(self.writer, value),
                .comptime_int, .int => try mzg.packInt(self.writer, value),
                .comptime_float, .float => try mzg.packFloat(self.writer, value),
                .optional => {
                    if (value) |payload| {
                        return self.pack(payload);
                    } else {
                        return mzg.packNil(self.writer);
                    }
                },
                .@"enum" => |info| {
                    if (std.meta.hasFn(Value, "mzgPack")) {
                        return value.mzgPack(self);
                    }
                    switch (behavior.@"enum") {
                        .value => return mzg.packInt(self.writer, @intFromEnum(value)),
                        .name => {
                            if (!info.is_exhaustive) {
                                @compileError("Cannot pack non-exhaustive enum using its name");
                            }
                            return mzg.packStr(self.writer, @tagName(value));
                        },
                    }
                },
                .enum_literal => {
                    if (behavior.@"enum" == .value) {
                        @compileError("Cannot pack enum literal when behavior requries the value of the enum is packed");
                    }

                    return mzg.packStr(self.writer, @tagName(value));
                },
                .@"union" => |info| {
                    if (std.meta.hasFn(Value, "mzgPack")) {
                        return value.mzgPack(self);
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
                    if (std.meta.hasFn(Value, "mzgPack")) {
                        return value.mzgPack(self);
                    }
                    if (info.is_tuple) {
                        try mzg.packArray(self.writer, info.fields.len);
                        inline for (info.fields) |field| {
                            try self.pack(@field(value, field.name));
                        }
                        return;
                    }

                    switch (behavior.@"struct") {
                        .array => {
                            try mzg.packArray(self.writer, info.fields.len);
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

                                try mzg.packMap(self.writer, non_null_len);
                                inline for (info.fields) |field| {
                                    if (@typeInfo(field.type) == .optional) {
                                        if (@field(value, field.name) != null) {
                                            try mzg.packStr(self.writer, field.name);
                                            try self.pack(@field(value, field.name));
                                        }
                                    } else {
                                        try mzg.packStr(self.writer, field.name);
                                        try self.pack(@field(value, field.name));
                                    }
                                }
                            } else {
                                try mzg.packMap(self.writer, info.fields.len);
                                inline for (info.fields) |field| {
                                    try mzg.packStr(self.writer, field.name);
                                    try self.pack(@field(value, field.name));
                                }
                            }
                        },
                    }
                },
                .error_set => {
                    return switch (behavior.@"error") {
                        .name => mzg.packStr(self.writer, @errorName(value)),
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
                        if (ptr.size == .many and ptr.sentinel() == null) {
                            @compileError("Cannot pack '" ++ @typeName(Value) ++ "' without sentinel");
                        }

                        const slice = if (ptr.size == .many) std.mem.span(value) else value;

                        if (ptr.child == u8) {
                            return switch (behavior.byte_slice) {
                                .str => mzg.packStr(self.writer, slice),
                                .bin => mzg.packBin(self.writer, slice),
                            };
                        }

                        try mzg.packArray(self.writer, slice.len);
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
