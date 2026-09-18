internal import CPlaydate

extension System {
    /// A system language. Wraps `PDLanguage`.
    public enum Language: UInt32, Sendable {
        case english = 0
        case japanese = 1
        /// The current system language; only meaningful for `localizedText(forKey:language:)`.
        case system = 2

        // Unknown C values fall back to English.
        init(_ language: PDLanguage) {
            self = Language(rawValue: UInt32(language.rawValue)) ?? .english
        }
        var cValue: PDLanguage { PDLanguage(PDLanguage.RawValue(rawValue)) }
    }
}
