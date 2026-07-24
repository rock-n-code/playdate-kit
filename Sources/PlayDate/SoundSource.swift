//
//  SoundSource.swift
//  SoundSource, FilePlayer, AudioSample, and SamplePlayer wrappers.
//

internal import CPlaydate

extension Sound {
    /// A source of audio: the base class of `FilePlayer`, `SamplePlayer`,
    /// `Synth`, `DelayLineTap`, and `CallbackSource`. Wraps `SoundSource`.
    public class Source {
        private static var api: playdate_sound_source { snd.source.pointee }

        /// The underlying C object. Set once, immediately after creation.
        var pointer: OpaquePointer!
        let isOwned: Bool
        var finishCallback: ((Source) -> Void)?

        init(pointer: OpaquePointer?, isOwned: Bool) {
            self.pointer = pointer
            self.isOwned = isOwned
        }

        /// Sets the playback volume for the left and right channels, 0...1.
        public func setVolume(left: Float, right: Float) {
            Source.api.setVolume.unsafelyUnwrapped(pointer, left, right)
        }

        /// Sets the playback volume of both channels.
        public func setVolume(_ volume: Float) {
            setVolume(left: volume, right: volume)
        }

        /// The playback volume of the left and right channels.
        public var volume: (left: Float, right: Float) {
            var left: Float = 0, right: Float = 0
            Source.api.getVolume.unsafelyUnwrapped(pointer, &left, &right)
            return (left, right)
        }

        public var isPlaying: Bool {
            Source.api.isPlaying.unsafelyUnwrapped(pointer) != 0
        }

        /// Sets a function called when the source finishes playing.
        public func setFinishCallback(_ callback: ((Source) -> Void)?) {
            finishCallback = callback
            if callback != nil {
                Source.api.setFinishCallback.unsafelyUnwrapped(pointer, { _, userdata in
                    guard let userdata else { return }
                    let source = Unmanaged<Source>.fromOpaque(userdata).takeUnretainedValue()
                    source.finishCallback?(source)
                }, Unmanaged.passUnretained(self).toOpaque())
            } else {
                Source.api.setFinishCallback.unsafelyUnwrapped(pointer, nil, nil)
            }
        }
    }

    /// A source that produces audio by calling back into Swift.
    public final class CallbackSource: Source {
        /// Fills the sample buffers and returns `true` if output was
        /// produced. `right` is non-nil only for stereo sources.
        public typealias Callback = (_ left: UnsafeMutableBufferPointer<Int16>,
                                     _ right: UnsafeMutableBufferPointer<Int16>?) -> Bool

        let callback: Callback

        /// Sources created through the top-level `Sound.addSource` are kept
        /// alive here until removed with `Sound.removeSource`.
        nonisolated(unsafe) static var live: [CallbackSource] = []

        init(callback: @escaping Callback) {
            self.callback = callback
            super.init(pointer: nil, isOwned: false)
        }

        var contextPointer: UnsafeMutableRawPointer {
            Unmanaged.passUnretained(self).toOpaque()
        }

        static let trampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutablePointer<Int16>?,
                                               UnsafeMutablePointer<Int16>?, Int32) -> Int32 = { context, left, right, length in
            guard let context, let left else { return 0 }
            let source = Unmanaged<CallbackSource>.fromOpaque(context).takeUnretainedValue()
            let leftBuffer = UnsafeMutableBufferPointer(start: left, count: Int(length))
            let rightBuffer = right.map { UnsafeMutableBufferPointer(start: $0, count: Int(length)) }
            return source.callback(leftBuffer, rightBuffer) ? 1 : 0
        }

        /// Attaches the C object created for this source.
        func adopt(pointer: OpaquePointer) {
            self.pointer = pointer
            CallbackSource.live.append(self)
        }
    }

    // MARK: - FilePlayer

    /// Streams audio from a file. Wraps `FilePlayer`.
    public final class FilePlayer: Source {
        private static var api: playdate_sound_fileplayer { snd.fileplayer.pointee }

        var loopCallback: ((FilePlayer) -> Void)?
        var fadeCallback: ((FilePlayer) -> Void)?
        var mp3DataSource: ((UnsafeMutableBufferPointer<UInt8>) -> Int)?
        private var retainedRateModulator: SignalValue?

        override init(pointer: OpaquePointer?, isOwned: Bool) {
            super.init(pointer: pointer, isOwned: isOwned)
        }

        public convenience init() {
            self.init(pointer: FilePlayer.api.newPlayer.unsafelyUnwrapped().unsafelyUnwrapped,
                      isOwned: true)
        }

        /// Creates a player and loads the audio file at `path`.
        public convenience init(path: String) throws(PlaydateError) {
            self.init()
            try load(path: path)
        }

        deinit {
            if isOwned {
                FilePlayer.api.freePlayer.unsafelyUnwrapped(pointer)
            }
        }

        /// Prepares the player to stream the file at `path`.
        public func load(path: String) throws(PlaydateError) {
            let loaded = path.withPlaydateCString {
                FilePlayer.api.loadIntoPlayer.unsafelyUnwrapped(pointer, $0) != 0
            }
            if !loaded {
                throw PlaydateError(message: "unable to load audio file: \(path)")
            }
        }

        /// Sets the length of the stream buffer, in seconds. Default 0.25.
        public func setBufferLength(_ seconds: Float) {
            FilePlayer.api.setBufferLength.unsafelyUnwrapped(pointer, seconds)
        }

        /// Starts playback, looping `repeat` times; 0 loops endlessly.
        @discardableResult
        public func play(repeat repeatCount: Int = 1) -> Bool {
            FilePlayer.api.play.unsafelyUnwrapped(pointer, Int32(repeatCount)) != 0
        }

        public func pause() {
            FilePlayer.api.pause.unsafelyUnwrapped(pointer)
        }

        public func stop() {
            FilePlayer.api.stop.unsafelyUnwrapped(pointer)
        }

        /// The file's length in seconds.
        public var length: Float {
            FilePlayer.api.getLength.unsafelyUnwrapped(pointer)
        }

        /// The playback position in seconds.
        public var offset: Float {
            get { FilePlayer.api.getOffset.unsafelyUnwrapped(pointer) }
            set { FilePlayer.api.setOffset.unsafelyUnwrapped(pointer, newValue) }
        }

        /// The playback rate; 1 is normal speed, negative values are not
        /// supported.
        public var rate: Float {
            get { FilePlayer.api.getRate.unsafelyUnwrapped(pointer) }
            set { FilePlayer.api.setRate.unsafelyUnwrapped(pointer, newValue) }
        }

        /// Loops playback between `start` and `end` (seconds) while playing
        /// with `repeat` 0. An `end` of 0 means the end of the file.
        public func setLoopRange(start: Float, end: Float) {
            FilePlayer.api.setLoopRange.unsafelyUnwrapped(pointer, start, end)
        }

        /// Whether playback underran because the file could not be read fast
        /// enough.
        public var didUnderrun: Bool {
            FilePlayer.api.didUnderrun.unsafelyUnwrapped(pointer) != 0
        }

        /// Stops playback (instead of looping the buffer) on underrun.
        public func setStopOnUnderrun(_ flag: Bool) {
            FilePlayer.api.setStopOnUnderrun.unsafelyUnwrapped(pointer, flag ? 1 : 0)
        }

        /// Sets a function called every time playback loops.
        public func setLoopCallback(_ callback: ((FilePlayer) -> Void)?) {
            loopCallback = callback
            if callback != nil {
                FilePlayer.api.setLoopCallback.unsafelyUnwrapped(pointer, { _, userdata in
                    guard let userdata else { return }
                    let player = Unmanaged<FilePlayer>.fromOpaque(userdata).takeUnretainedValue()
                    player.loopCallback?(player)
                }, Unmanaged.passUnretained(self).toOpaque())
            } else {
                FilePlayer.api.setLoopCallback.unsafelyUnwrapped(pointer, nil, nil)
            }
        }

        /// Fades the volume to the given levels over `length` sample frames,
        /// then calls `completion`.
        public func fadeVolume(left: Float, right: Float, length: Int32,
                               completion: ((FilePlayer) -> Void)? = nil) {
            fadeCallback = completion
            if completion != nil {
                FilePlayer.api.fadeVolume.unsafelyUnwrapped(pointer, left, right, length, { _, userdata in
                    guard let userdata else { return }
                    let player = Unmanaged<FilePlayer>.fromOpaque(userdata).takeUnretainedValue()
                    player.fadeCallback?(player)
                }, Unmanaged.passUnretained(self).toOpaque())
            } else {
                FilePlayer.api.fadeVolume.unsafelyUnwrapped(pointer, left, right, length, nil, nil)
            }
        }

        /// Streams MP3 data from a callback instead of a file. The callback
        /// fills the buffer and returns the number of bytes written; return 0
        /// to signal the end of the stream.
        public func setMP3StreamSource(bufferLength: Float,
                                       _ dataSource: @escaping (UnsafeMutableBufferPointer<UInt8>) -> Int) {
            mp3DataSource = dataSource
            FilePlayer.api.setMP3StreamSource.unsafelyUnwrapped(pointer, { data, bytes, userdata in
                guard let userdata, let data else { return 0 }
                let player = Unmanaged<FilePlayer>.fromOpaque(userdata).takeUnretainedValue()
                let buffer = UnsafeMutableBufferPointer(start: data, count: Int(bytes))
                return Int32(player.mp3DataSource?(buffer) ?? 0)
            }, Unmanaged.passUnretained(self).toOpaque(), bufferLength)
        }

        /// Modulates the playback rate.
        public var rateModulator: SignalValue? {
            get { SignalValue.wrap(FilePlayer.api.getRateModulator.unsafelyUnwrapped(pointer)) }
            set {
                retainedRateModulator = newValue
                FilePlayer.api.setRateModulator.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }
    }

    // MARK: - AudioSample

    /// Audio data loaded into memory. Wraps `AudioSample`.
    public final class AudioSample {
        private static var api: playdate_sound_sample { snd.sample.pointee }

        let pointer: OpaquePointer
        let isOwned: Bool

        init(pointer: OpaquePointer, isOwned: Bool) {
            self.pointer = pointer
            self.isOwned = isOwned
        }

        /// Allocates a sample buffer with room for `byteCount` bytes.
        public convenience init(byteCount: Int) {
            self.init(pointer: AudioSample.api.newSampleBuffer.unsafelyUnwrapped(
                Int32(byteCount)).unsafelyUnwrapped, isOwned: true)
        }

        /// Loads the wav or aiff file at `path`.
        public convenience init(path: String) throws(PlaydateError) {
            let pointer = path.withPlaydateCString { AudioSample.api.load.unsafelyUnwrapped($0) }
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
            guard let pointer = AudioSample.api.newSampleFromData.unsafelyUnwrapped(
                data, format.cValue, sampleRate, Int32(byteCount), freeWhenDone ? 1 : 0) else {
                return nil
            }
            self.init(pointer: pointer, isOwned: true)
        }

        deinit {
            if isOwned {
                AudioSample.api.freeSample.unsafelyUnwrapped(pointer)
            }
        }

        /// Loads the file at `path` into this sample's buffer.
        public func load(path: String) throws(PlaydateError) {
            let loaded = path.withPlaydateCString {
                AudioSample.api.loadIntoSample.unsafelyUnwrapped(pointer, $0) != 0
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
            AudioSample.api.getData.unsafelyUnwrapped(pointer, &data, &format, &sampleRate, &byteLength)
            return (data, Format(format), sampleRate, byteLength)
        }

        /// The sample's length in seconds.
        public var length: Float {
            AudioSample.api.getLength.unsafelyUnwrapped(pointer)
        }

        /// Decompresses an ADPCM sample to 16-bit PCM so it can be used in a
        /// synth. Returns `false` if there is not enough memory.
        @discardableResult
        public func decompress() -> Bool {
            AudioSample.api.decompress.unsafelyUnwrapped(pointer) != 0
        }
    }

    // MARK: - SamplePlayer

    /// Plays an `AudioSample` from memory. Wraps `SamplePlayer`.
    public final class SamplePlayer: Source {
        private static var api: playdate_sound_sampleplayer { snd.sampleplayer.pointee }

        var loopCallback: ((SamplePlayer) -> Void)?
        private var retainedSample: AudioSample?
        private var retainedRateModulator: SignalValue?

        override init(pointer: OpaquePointer?, isOwned: Bool) {
            super.init(pointer: pointer, isOwned: isOwned)
        }

        public convenience init() {
            self.init(pointer: SamplePlayer.api.newPlayer.unsafelyUnwrapped().unsafelyUnwrapped,
                      isOwned: true)
        }

        /// Creates a player for the sample at `path`.
        public convenience init(path: String) throws(PlaydateError) {
            self.init()
            sample = try AudioSample(path: path)
        }

        deinit {
            if isOwned {
                SamplePlayer.api.freePlayer.unsafelyUnwrapped(pointer)
            }
        }

        /// The sample to play.
        public var sample: AudioSample? {
            get { retainedSample }
            set {
                retainedSample = newValue
                SamplePlayer.api.setSample.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }

        /// Starts playback at `rate`, looping `repeat` times; 0 loops
        /// endlessly, -1 loops ping-pong.
        @discardableResult
        public func play(repeat repeatCount: Int = 1, rate: Float = 1) -> Bool {
            SamplePlayer.api.play.unsafelyUnwrapped(pointer, Int32(repeatCount), rate) != 0
        }

        public func stop() {
            SamplePlayer.api.stop.unsafelyUnwrapped(pointer)
        }

        public func setPaused(_ paused: Bool) {
            SamplePlayer.api.setPaused.unsafelyUnwrapped(pointer, paused ? 1 : 0)
        }

        /// The sample's length in seconds.
        public var length: Float {
            SamplePlayer.api.getLength.unsafelyUnwrapped(pointer)
        }

        /// The playback position in seconds.
        public var offset: Float {
            get { SamplePlayer.api.getOffset.unsafelyUnwrapped(pointer) }
            set { SamplePlayer.api.setOffset.unsafelyUnwrapped(pointer, newValue) }
        }

        /// The playback rate; 1 is normal speed, negative plays backward.
        public var rate: Float {
            get { SamplePlayer.api.getRate.unsafelyUnwrapped(pointer) }
            set { SamplePlayer.api.setRate.unsafelyUnwrapped(pointer, newValue) }
        }

        /// Restricts playback to the given range of sample frames.
        public func setPlayRange(start: Int, end: Int) {
            SamplePlayer.api.setPlayRange.unsafelyUnwrapped(pointer, Int32(start), Int32(end))
        }

        /// Sets a function called every time playback loops.
        public func setLoopCallback(_ callback: ((SamplePlayer) -> Void)?) {
            loopCallback = callback
            if callback != nil {
                SamplePlayer.api.setLoopCallback.unsafelyUnwrapped(pointer, { _, userdata in
                    guard let userdata else { return }
                    let player = Unmanaged<SamplePlayer>.fromOpaque(userdata).takeUnretainedValue()
                    player.loopCallback?(player)
                }, Unmanaged.passUnretained(self).toOpaque())
            } else {
                SamplePlayer.api.setLoopCallback.unsafelyUnwrapped(pointer, nil, nil)
            }
        }

        /// Modulates the playback rate.
        public var rateModulator: SignalValue? {
            get { SignalValue.wrap(SamplePlayer.api.getRateModulator.unsafelyUnwrapped(pointer)) }
            set {
                retainedRateModulator = newValue
                SamplePlayer.api.setRateModulator.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }
    }
}
