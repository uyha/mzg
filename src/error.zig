pub fn PackError(Writer: type) type {
    return error{ValueTooBig} || if (@hasDecl(Writer, "Error")) Writer.Error;
}
