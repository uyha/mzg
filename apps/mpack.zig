pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.detectLeaks();
    const allocator = gpa.allocator();

    const app = try parseArguments(allocator);

    switch (app.direction) {
        .to_json => try msgpackToJson(allocator),
        .to_msgpack => {},
    }
}

fn parseArguments(allocator: std.mem.Allocator) !App {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var result: App = .init;

    var pos: usize = 0;
    var index: usize = 1;
    while (index < args.len) : (index += 1) {
        const arg = args[index];
        if (std.mem.startsWith(u8, arg, "--")) {} else {
            switch (pos) {
                0 => {
                    if (App.direction_map.get(arg)) |direction| {
                        result.direction = direction;
                    } else {
                        std.debug.print("Unexpected direction: {s}\n", .{arg});
                    }
                    pos += 1;
                },
                else => {},
            }
        }
    }

    return result;
}

fn msgpackToJson(allocator: std.mem.Allocator) !void {
    var pipe = msgpackPipe(
        8,
        std.io.getStdIn().reader(),
        std.io.getStdOut().writer(),
    );
    defer pipe.deinit(allocator);
    defer _ = std.io.getStdOut().write("\n") catch {};

    try pipe.pipe(allocator);
}

fn MsgpackPipe(
    comptime capacity: usize,
    comptime Reader: type,
    comptime Stream: type,
) type {
    return struct {
        const Self = @This();

        buffer: [capacity]u8 = @splat(0),
        size: usize = 0,
        reader: Reader,
        stream: Stream,
        containers: std.ArrayListUnmanaged(Container) = .empty,

        pub fn init(reader: Reader, stream: Stream) Self {
            return .{
                .reader = reader,
                .stream = stream,
            };
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            return self.containers.deinit(allocator);
        }

        fn lastContainer(self: *Self) ?*Container {
            return if (self.containers.items.len > 0) &self.containers.items[self.containers.items.len - 1] else null;
        }

        fn openArray(
            self: *Self,
            allocator: std.mem.Allocator,
            len: usize,
        ) !void {
            try self.containers.append(
                allocator,
                .{ .array = .{ .len = len, .consumed = 0 } },
            );
            try self.stream.beginArray();
        }
        fn openMap(
            self: *Self,
            allocator: std.mem.Allocator,
            len: usize,
        ) !void {
            try self.containers.append(
                allocator,
                .{ .map = .{ .len = len, .consumed = 0, .target = .key } },
            );
            try self.stream.beginObject();
        }
        fn openStr(self: *Self, allocator: std.mem.Allocator, len: usize) !void {
            try self.containers.append(
                allocator,
                .{ .str = .{ .len = len, .consumed = 0 } },
            );
            try self.stream.beginWriteRaw();
            try self.stream.stream.writeAll("\"");
        }
        fn closeContainer(self: *Self) !void {
            while (self.lastContainer()) |container| {
                switch (container.*) {
                    .array, .map => {
                        container.increseConsumed(1);
                    },
                    .str => {},
                }
                if (!container.isFilled()) {
                    return;
                }
                switch (container.*) {
                    .array => {
                        try self.stream.endArray();
                    },
                    .map => |*c| {
                        c.target = if (c.target == .key) .value else .key;
                        if (c.consumed == c.len) {
                            try self.stream.endObject();
                        }
                    },
                    .str => {
                        try self.stream.stream.writeAll("\"");
                        self.stream.endWriteRaw();
                    },
                }

                _ = self.containers.pop();
            }
        }

        fn write(self: *Self, value: anytype) !void {
            if (self.lastContainer()) |container| {
                switch (container.*) {
                    .array => {
                        try self.stream.write(value);
                    },
                    .map => |*c| {
                        switch (c.target) {
                            .key => {
                                if (@TypeOf(value) != []const u8) {
                                    unreachable;
                                }
                                try self.stream.objectField(value);
                                c.target = .value;
                            },
                            .value => {
                                try self.stream.write(value);
                                c.target = .key;
                            },
                        }
                    },
                    .str => {
                        const Value = @TypeOf(value);

                        if (Value != []const u8 and Value != []u8) {
                            unreachable;
                        }

                        try self.stream.stream.writeAll(value);
                        container.increseConsumed(value.len);
                    },
                }
            } else {
                try self.stream.write(value);
            }

            try self.closeContainer();
        }

        fn writeBin(self: *Self, values: []const u8) !void {
            try self.stream.beginArray();
            for (values) |value| {
                try self.stream.print("0x{X:02}", .{value});
            }
            try self.stream.endArray();
            try self.closeContainer();
        }

        pub fn pipe(self: *Self, allocator: std.mem.Allocator) !void {
            while (self.reader.read(self.buffer[self.size..])) |bytes| {
                if (bytes == 0) break;

                self.size += bytes;

                var parsed_bytes: usize = 0;

                while (parsed_bytes < self.size) {
                    const slice = self.buffer[parsed_bytes..self.size];

                    const format = try mzg.format.parse(slice);

                    if (self.lastContainer()) |container| {
                        if (container.* == .str) {
                            const remaining = container.remaining();
                            try self.write(slice[0..remaining]);
                            parsed_bytes += remaining;
                            continue;
                        }
                    }

                    switch (format) {
                        .array => {
                            var out: u32 = undefined;
                            parsed_bytes += try mzg.unpackArray(slice, &out);
                            try self.openArray(allocator, out);
                        },
                        .map => {
                            var out: u32 = undefined;
                            parsed_bytes += try mzg.unpackMap(slice, &out);
                            try self.openMap(allocator, out);
                        },
                        .str => {
                            var out: u32 = undefined;
                            const size = try mzg.unpackStrLen(slice, &out);

                            if (out + size < slice.len) {
                                try self.write('"');
                                try self.write(slice[size..][0..out]);
                                try self.write('"');

                                parsed_bytes += out + size;
                                continue;
                            }

                            try self.openStr(allocator, out);
                            try self.write(slice[size..]);
                            parsed_bytes += slice.len;
                        },
                        else => {
                            var out: mzg.Value = undefined;
                            parsed_bytes += mzg.unpack(
                                slice,
                                &out,
                            ) catch |err| switch (err) {
                                error.BufferUnderRun => break,
                                else => return err,
                            };

                            switch (out) {
                                .nil => {},
                                .int => |int| switch (int) {
                                    inline else => |inner| try self.write(inner),
                                },
                                .float => |float| switch (float) {
                                    inline else => |inner| try self.write(inner),
                                },
                                .bin => |bin| try self.writeBin(bin),
                                inline else => |value| try self.write(value),
                            }
                        },
                    }
                }

                std.mem.copyForwards(
                    u8,
                    self.buffer[0..],
                    self.buffer[parsed_bytes..],
                );
                self.size -= parsed_bytes;
            } else |err| {
                return err;
            }
        }
    };
}
fn msgpackPipe(
    comptime capacity: usize,
    reader: anytype,
    writer: anytype,
) MsgpackPipe(
    capacity,
    @TypeOf(reader),
    std.json.WriteStream(@TypeOf(writer), .{ .checked_to_fixed_depth = 256 }),
) {
    return .init(
        reader,
        std.json.writeStream(writer, .{}),
    );
}

const Container = union(enum) {
    const Self = @This();

    map: struct { len: usize, consumed: usize, target: enum { key, value } },
    array: struct { len: usize, consumed: usize },
    str: struct { len: usize, consumed: usize },

    pub fn increseConsumed(self: *Self, addition: usize) void {
        return switch (self.*) {
            inline else => |*value| value.consumed += addition,
        };
    }
    pub fn remaining(self: *const Self) usize {
        return switch (self.*) {
            inline else => |*value| value.len - value.consumed,
        };
    }
    pub fn isFilled(self: *const Self) bool {
        return self.remaining() == 0;
    }
};
const Direction = enum { to_json, to_msgpack };
const App = struct {
    direction: Direction = .to_json,

    pub const init: @This() = .{};

    pub const direction_map = std.StaticStringMap(Direction).initComptime(
        [_]struct { []const u8, Direction }{
            .{ "to-json", .to_json },
            .{ "to-msgpack", .to_msgpack },
        },
    );
};
const std = @import("std");
const mzg = @import("mzg");
