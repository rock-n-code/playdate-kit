extension System {
    /// OS, language, and pdx version information, mirroring `PDInfo`.
    public struct Info: Sendable {
        /// The Playdate OS version.
        public let osVersion: UInt32
        /// The system language.
        public let language: Language
        /// The version of the game's pdx.
        public let pdxVersion: UInt32
    }
}
