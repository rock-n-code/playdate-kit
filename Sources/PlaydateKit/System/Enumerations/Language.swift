internal import CPlaydate

extension System {
    /// The system language.
    public enum Language: UInt32, Sendable {
        case english = 0
        case japanese = 1
        /// Only meaningful as an argument to `localizedText(forKey:language:)`.
        case system = 2

        init(_ language: PDLanguage) {
            self = Language(rawValue: UInt32(language.rawValue)) ?? .english
        }
        var cValue: PDLanguage { PDLanguage(PDLanguage.RawValue(rawValue)) }
    }
}
