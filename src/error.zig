pub fn PackError(Writer: type) type {
    return error{
        ValueInvalid,
        Unsupported,
    } || if (@hasDecl(Writer, "Error")) Writer.Error;
}

pub const UnpackError = error{
    BufferUnderRun,
    FormatUnrecognized,
    TypeIncompatible,
    ValueInvalid,
};
