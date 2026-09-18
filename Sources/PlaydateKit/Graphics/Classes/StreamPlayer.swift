internal import CPlaydate

/// `playdate->graphics->videostream`.
private var streamAPI: UnsafePointer<playdate_videostream> { Playdate.videoStreamAPI.unsafelyUnwrapped }

extension Graphics {
    /// Streams video and audio from a file or connection. Wraps `LCDStreamPlayer`.
    /// Retains its source until replaced.
    public final class StreamPlayer {
        let pointer: OpaquePointer
        /// The C player reads the source; non-copyable `File.Handle` needs its own slot.
        private var retainedSource: AnyObject?
        private var retainedFile: File.Handle?

        public init() {
            pointer = streamAPI.pointee.newPlayer.unsafelyUnwrapped().unsafelyUnwrapped
        }

        deinit {
            streamAPI.pointee.freePlayer.unsafelyUnwrapped(pointer)
        }

        /// Buffer sizes, in bytes.
        public func setBufferSize(video: Int, audio: Int) {
            streamAPI.pointee.setBufferSize.unsafelyUnwrapped(pointer, Int32(video), Int32(audio))
        }

        /// Takes ownership; the handle closes when replaced or on deinit.
        public func setFile(_ file: consuming File.Handle) {
            streamAPI.pointee.setFile.unsafelyUnwrapped(pointer, file.pointer)
            retainedFile = consume file
            retainedSource = nil
        }

        public func setHTTPConnection(_ connection: Network.HTTPConnection) {
            streamAPI.pointee.setHTTPConnection.unsafelyUnwrapped(pointer, connection.pointer)
            retainedSource = connection
            retainedFile = nil
        }

        public func setTCPConnection(_ connection: Network.TCPConnection) {
            streamAPI.pointee.setTCPConnection.unsafelyUnwrapped(pointer, connection.pointer)
            retainedSource = connection
            retainedFile = nil
        }

        /// Borrowed. The same wrapper is returned while the underlying player is unchanged,
        /// so callbacks registered on it persist.
        public var filePlayer: Sound.FilePlayer? {
            guard let player = streamAPI.pointee.getFilePlayer.unsafelyUnwrapped(pointer) else { return nil }
            if let cached = cachedFilePlayer, cached.pointer == player {
                return cached
            }
            let wrapper = Sound.FilePlayer(pointer: player, isOwned: false)
            cachedFilePlayer = wrapper
            return wrapper
        }

        private var cachedFilePlayer: Sound.FilePlayer?

        /// Borrowed; keep this player alive while using it.
        public var videoPlayer: VideoPlayer? {
            guard let player = streamAPI.pointee.getVideoPlayer.unsafelyUnwrapped(pointer) else { return nil }
            return VideoPlayer(pointer: player, isOwned: false)
        }

        /// Returns `true` if a frame was drawn.
        @discardableResult
        public func update() -> Bool {
            streamAPI.pointee.update.unsafelyUnwrapped(pointer)
        }

        public var bufferedFrameCount: Int {
            Int(streamAPI.pointee.getBufferedFrameCount.unsafelyUnwrapped(pointer))
        }

        /// Bytes read from the source so far.
        public var bytesRead: UInt32 {
            streamAPI.pointee.getBytesRead.unsafelyUnwrapped(pointer)
        }
    }
}
