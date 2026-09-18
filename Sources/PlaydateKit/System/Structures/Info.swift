extension System {
    /// OS, language, and SDK version information. Mirrors `PDInfo`.
    public struct Info: Sendable {
        /// E.g. 20705 for 2.7.5.
        public let osVersion: UInt32
        public let language: Language
        /// The pdxinfo `pdxversion`: the SDK version the game was built with.
        public let pdxVersion: UInt32
    }
}
