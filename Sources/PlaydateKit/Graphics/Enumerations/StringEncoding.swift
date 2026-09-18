internal import CPlaydate

extension Graphics {
    /// Text encoding for the C text functions. Wraps `PDStringEncoding`.
    /// The Swift text wrappers always pass UTF-8.
    public enum StringEncoding: UInt32, Sendable {
        case ascii = 0
        case utf8 = 1
        /// UTF-16, little-endian.
        case utf16LittleEndian = 2

        var cValue: PDStringEncoding { PDStringEncoding(PDStringEncoding.RawValue(rawValue)) }
    }
}
