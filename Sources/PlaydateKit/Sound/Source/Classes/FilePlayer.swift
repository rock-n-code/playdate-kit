internal import CPlaydate

extension Sound {
    /// Streams audio from a file. Wraps `FilePlayer`.
    public final class FilePlayer: Source {
        private static var api: UnsafePointer<playdate_sound_fileplayer> { Playdate.filePlayerAPI.unsafelyUnwrapped }

        var loopCallback: ((FilePlayer) -> Void)?
        var fadeCallback: ((FilePlayer) -> Void)?
        var mp3DataSource: ((UnsafeMutableBufferPointer<UInt8>) -> Int)?
        private var retainedRateModulator: SignalValue?

        override init(pointer: OpaquePointer?, isOwned: Bool) {
            super.init(pointer: pointer, isOwned: isOwned)
        }

        public convenience init() {
            self.init(pointer: FilePlayer.api.pointee.newPlayer.unsafelyUnwrapped().unsafelyUnwrapped,
                      isOwned: true)
        }

        /// Creates a player and loads the audio file at `path`.
        public convenience init(path: String) throws(PlaydateError) {
            self.init()
            try load(path: path)
        }

        deinit {
            if isOwned {
                FilePlayer.api.pointee.freePlayer.unsafelyUnwrapped(pointer)
            }
        }

        /// Prepares the player to stream the file at `path`.
        public func load(path: String) throws(PlaydateError) {
            let loaded = path.withPlaydateCString {
                FilePlayer.api.pointee.loadIntoPlayer.unsafelyUnwrapped(pointer, $0) != 0
            }
            if !loaded {
                throw PlaydateError(message: "unable to load audio file: \(path)")
            }
        }

        /// Sets the length of the stream buffer, in seconds. Default 0.25.
        public func setBufferLength(_ seconds: Float) {
            FilePlayer.api.pointee.setBufferLength.unsafelyUnwrapped(pointer, seconds)
        }

        /// Starts playback, looping `repeat` times; 0 loops endlessly.
        @discardableResult
        public func play(repeat repeatCount: Int = 1) -> Bool {
            FilePlayer.api.pointee.play.unsafelyUnwrapped(pointer, Int32(repeatCount)) != 0
        }

        /// Pauses playback.
        public func pause() {
            FilePlayer.api.pointee.pause.unsafelyUnwrapped(pointer)
        }

        /// Stops playback.
        public func stop() {
            FilePlayer.api.pointee.stop.unsafelyUnwrapped(pointer)
        }

        /// The file's length in seconds.
        public var length: Float {
            FilePlayer.api.pointee.getLength.unsafelyUnwrapped(pointer)
        }

        /// The playback position in seconds.
        public var offset: Float {
            get { FilePlayer.api.pointee.getOffset.unsafelyUnwrapped(pointer) }
            set { FilePlayer.api.pointee.setOffset.unsafelyUnwrapped(pointer, newValue) }
        }

        /// The playback rate; 1 is normal speed, negative values are not
        /// supported.
        public var rate: Float {
            get { FilePlayer.api.pointee.getRate.unsafelyUnwrapped(pointer) }
            set { FilePlayer.api.pointee.setRate.unsafelyUnwrapped(pointer, newValue) }
        }

        /// Loops playback between `start` and `end` (seconds) while playing
        /// with `repeat` 0. An `end` of 0 means the end of the file.
        public func setLoopRange(start: Float, end: Float) {
            FilePlayer.api.pointee.setLoopRange.unsafelyUnwrapped(pointer, start, end)
        }

        /// Whether playback underran because the file could not be read fast
        /// enough.
        public var didUnderrun: Bool {
            FilePlayer.api.pointee.didUnderrun.unsafelyUnwrapped(pointer) != 0
        }

        /// Stops playback (instead of looping the buffer) on underrun.
        public func setStopOnUnderrun(_ flag: Bool) {
            FilePlayer.api.pointee.setStopOnUnderrun.unsafelyUnwrapped(pointer, flag ? 1 : 0)
        }

        /// Sets a function called every time playback loops.
        public func setLoopCallback(_ callback: ((FilePlayer) -> Void)?) {
            loopCallback = callback
            if callback != nil {
                FilePlayer.api.pointee.setLoopCallback.unsafelyUnwrapped(pointer, { _, userdata in
                    guard let userdata else { return }
                    let player = Unmanaged<FilePlayer>.fromOpaque(userdata).takeUnretainedValue()
                    player.loopCallback?(player)
                }, Unmanaged.passUnretained(self).toOpaque())
            } else {
                FilePlayer.api.pointee.setLoopCallback.unsafelyUnwrapped(pointer, nil, nil)
            }
        }

        /// Fades the volume to the given levels over `length` sample frames,
        /// then calls `completion`.
        public func fadeVolume(left: Float, right: Float, length: Int32,
                               completion: ((FilePlayer) -> Void)? = nil) {
            fadeCallback = completion
            if completion != nil {
                FilePlayer.api.pointee.fadeVolume.unsafelyUnwrapped(pointer, left, right, length, { _, userdata in
                    guard let userdata else { return }
                    let player = Unmanaged<FilePlayer>.fromOpaque(userdata).takeUnretainedValue()
                    player.fadeCallback?(player)
                }, Unmanaged.passUnretained(self).toOpaque())
            } else {
                FilePlayer.api.pointee.fadeVolume.unsafelyUnwrapped(pointer, left, right, length, nil, nil)
            }
        }

        /// Streams MP3 data from a callback instead of a file. The callback
        /// fills the buffer and returns the number of bytes written; return 0
        /// to signal the end of the stream.
        public func setMP3StreamSource(bufferLength: Float,
                                       _ dataSource: @escaping (UnsafeMutableBufferPointer<UInt8>) -> Int) {
            mp3DataSource = dataSource
            FilePlayer.api.pointee.setMP3StreamSource.unsafelyUnwrapped(pointer, { data, bytes, userdata in
                guard let userdata, let data else { return 0 }
                let player = Unmanaged<FilePlayer>.fromOpaque(userdata).takeUnretainedValue()
                let buffer = UnsafeMutableBufferPointer(start: data, count: Int(bytes))
                return Int32(player.mp3DataSource?(buffer) ?? 0)
            }, Unmanaged.passUnretained(self).toOpaque(), bufferLength)
        }

        /// Modulates the playback rate.
        public var rateModulator: SignalValue? {
            get { SignalValue.wrap(FilePlayer.api.pointee.getRateModulator.unsafelyUnwrapped(pointer)) }
            set {
                retainedRateModulator = newValue
                FilePlayer.api.pointee.setRateModulator.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }
    }
}
