internal import CPlaydate

extension Sound {
    /// Audio data loaded into memory. Wraps `AudioSample`.
    public final class AudioSample {
        private static var api: UnsafePointer<playdate_sound_sample> { Playdate.sampleAPI.unsafelyUnwrapped }

        let pointer: OpaquePointer
        let isOwned: Bool

        init(pointer: OpaquePointer, isOwned: Bool) {
            self.pointer = pointer
            self.isOwned = isOwned
        }

        /// Allocates a sample buffer with room for `byteCount` bytes.
        public convenience init(byteCount: Int) {
            self.init(pointer: AudioSample.api.pointee.newSampleBuffer.unsafelyUnwrapped(
                Int32(byteCount)).unsafelyUnwrapped, isOwned: true)
        }

        /// Loads the wav or aiff file at `path`.
        public convenience init(path: String) throws(PlaydateError) {
            let pointer = path.withPlaydateCString { AudioSample.api.pointee.load.unsafelyUnwrapped($0) }
            guard let pointer else {
                throw PlaydateError(message: "unable to load sample: \(path)")
            }
            self.init(pointer: pointer, isOwned: true)
        }

        /// Creates a sample referencing existing sample data. If
        /// `freeWhenDone` is `true`, the OS frees `data` when the sample is
        /// freed; otherwise the caller must keep `data` valid for the
        /// sample's lifetime.
        public convenience init?(data: UnsafeMutablePointer<UInt8>, format: Format,
                                 sampleRate: UInt32, byteCount: Int, freeWhenDone: Bool) {
            guard let pointer = AudioSample.api.pointee.newSampleFromData.unsafelyUnwrapped(
                data, format.cValue, sampleRate, Int32(byteCount), freeWhenDone ? 1 : 0) else {
                return nil
            }
            self.init(pointer: pointer, isOwned: true)
        }

        deinit {
            if isOwned {
                AudioSample.api.pointee.freeSample.unsafelyUnwrapped(pointer)
            }
        }

        /// Loads the file at `path` into this sample's buffer.
        public func load(path: String) throws(PlaydateError) {
            let loaded = path.withPlaydateCString {
                AudioSample.api.pointee.loadIntoSample.unsafelyUnwrapped(pointer, $0) != 0
            }
            if !loaded {
                throw PlaydateError(message: "unable to load sample: \(path)")
            }
        }

        /// The sample's raw data, format, and rate.
        public var data: (data: UnsafeMutablePointer<UInt8>?, format: Format,
                          sampleRate: UInt32, byteLength: UInt32) {
            var data: UnsafeMutablePointer<UInt8>?
            var format = kSound16bitMono
            var sampleRate: UInt32 = 0, byteLength: UInt32 = 0
            AudioSample.api.pointee.getData.unsafelyUnwrapped(pointer, &data, &format, &sampleRate, &byteLength)
            return (data, Format(format), sampleRate, byteLength)
        }

        /// The sample's length in seconds.
        public var length: Float {
            AudioSample.api.pointee.getLength.unsafelyUnwrapped(pointer)
        }

        /// Decompresses an ADPCM sample to 16-bit PCM so it can be used in a
        /// synth. Returns `false` if there is not enough memory.
        @discardableResult
        public func decompress() -> Bool {
            AudioSample.api.pointee.decompress.unsafelyUnwrapped(pointer) != 0
        }
    }
}
