internal import CPlaydate

extension Sound {
    /// The format of sample data.
    public enum Format: UInt32, Sendable {
        case mono8bit = 0
        case stereo8bit = 1
        case mono16bit = 2
        case stereo16bit = 3
        case monoADPCM = 4
        case stereoADPCM = 5

        init(_ format: SoundFormat) { self = Format(rawValue: UInt32(format.rawValue)) ?? .mono16bit }
        var cValue: SoundFormat { SoundFormat(SoundFormat.RawValue(rawValue)) }

        public var isStereo: Bool { rawValue & 1 != 0 }
        public var is16bit: Bool { rawValue >= 2 && rawValue < 4 }
        public var bytesPerFrame: Int { Int(SoundFormat_bytesPerFrame(cValue)) }
    }
}
