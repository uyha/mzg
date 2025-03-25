pub fn PackError(Writer: type) type {
    return error{ValueInvalid} || if (@hasDecl(Writer, "Error")) Writer.Error;
}
