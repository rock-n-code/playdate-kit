internal import CPlaydate

extension Graphics {
    /// The encoding of text passed to the text functions.
    public enum StringEncoding: UInt32, Sendable {
        case ascii = 0
        case utf8 = 1
        case utf16LittleEndian = 2

        var cValue: PDStringEncoding { PDStringEncoding(PDStringEncoding.RawValue(rawValue)) }
    }
}
