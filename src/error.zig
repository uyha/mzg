pub fn PackError(Writer: type) type {
    return error{
        ValueInvalid,
    } || if (@hasDecl(Writer, "Error")) Writer.Error;
}

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

pub const UnpackAllocateError = UnpackError || error{
    /// This error is never thrown with the default unpacking, but it is here to
    /// let custom unpacking return memory error when it cannot allocate memory.
    OutOfMemory,
};
