pub const PackError = error{ValueInvalid} || Writer.Error;
pub const UnpackError = error{
    /// The format marker indicates more bytes than what the buffer has
    /// available
    BufferUnderRun,
    /// The format does not exist in the MessagePack's specification
    FormatUnrecognized,
    /// The buffer cannot be unpacked into the destination
    TypeIncompatible,
    /// The value in the buffer is outside the range of the destination
    ValueInvalid,
};

/// `Allocator.Error` is never thrown with the default unpacking, but it is here to
/// let custom unpacking return memory error when it cannot allocate memory.
pub const UnpackAllocateError = UnpackError || Allocator.Error;

const std = @import("std");
const Writer = std.Io.Writer;
const Allocator = std.mem.Allocator;
