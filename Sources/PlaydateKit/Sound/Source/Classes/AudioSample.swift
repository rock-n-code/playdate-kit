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

        /// An empty buffer sized for a `byteCount`-byte file; fill it with `load(path:)`.
        public convenience init(byteCount: Int) {
            self.init(pointer: AudioSample.api.pointee.newSampleBuffer.unsafelyUnwrapped(
                Int32(byteCount)).unsafelyUnwrapped, isOwned: true)
        }

        /// Loads the wav or aiff file at `path`.
        public convenience init(path: String) throws(PlaydateError) {
            let pointer = path.withCString { AudioSample.api.pointee.load.unsafelyUnwrapped($0) }
            guard let pointer else {
                throw PlaydateError(message: "unable to load sample: \(path)")
            }
            self.init(pointer: pointer, isOwned: true)
        }

        /// References `data` without copying; it must outlive the sample, which frees it
        /// if `freeWhenDone`. Returns `nil` on failure.
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

        public func load(path: String) throws(PlaydateError) {
            let loaded = path.withCString {
                AudioSample.api.pointee.loadIntoSample.unsafelyUnwrapped(pointer, $0) != 0
            }
            if !loaded {
                throw PlaydateError(message: "unable to load sample: \(path)")
            }
        }

        /// Data pointer (owned by the sample), format, rate in Hz, and length in bytes.
        public var data: (data: UnsafeMutablePointer<UInt8>?, format: Format,
                          sampleRate: UInt32, byteLength: UInt32) {
            var data: UnsafeMutablePointer<UInt8>?
            var format = kSound16bitMono
            var sampleRate: UInt32 = 0, byteLength: UInt32 = 0
            AudioSample.api.pointee.getData.unsafelyUnwrapped(pointer, &data, &format, &sampleRate, &byteLength)
            return (data, Format(format), sampleRate, byteLength)
        }

        /// Length in seconds.
        public var length: Float {
            AudioSample.api.pointee.getLength.unsafelyUnwrapped(pointer)
        }

        /// Decompresses ADPCM to 16-bit PCM (4x memory), needed for synths and reverse
        /// play. Returns `false` if out of memory.
        @discardableResult
        public func decompress() -> Bool {
            AudioSample.api.pointee.decompress.unsafelyUnwrapped(pointer) != 0
        }
    }
}
