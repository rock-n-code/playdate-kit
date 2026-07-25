extension System {
    /// OS, language, and pdx version information, mirroring `PDInfo`.
    public struct Info: Sendable {
        public let osVersion: UInt32
        public let language: Language
        public let pdxVersion: UInt32
    }
}
