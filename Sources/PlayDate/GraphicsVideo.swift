//
//  GraphicsVideo.swift
//  VideoPlayer and StreamPlayer wrappers around LCDVideoPlayer /
//  LCDStreamPlayer (playdate->graphics->video / ->videostream).
//

internal import CPlaydate

private var videoAPI: playdate_video { gfx.video.pointee }
private var streamAPI: playdate_videostream { gfx.videostream.pointee }

extension Graphics {
    /// Plays .pdv video files. Wraps `LCDVideoPlayer`.
    public final class VideoPlayer {
        let pointer: OpaquePointer
        let isOwned: Bool
        /// Retains the render context bitmap while the player uses it.
        private var retainedContext: Bitmap?

        init(pointer: OpaquePointer, isOwned: Bool) {
            self.pointer = pointer
            self.isOwned = isOwned
        }

        /// Opens the .pdv file at `path`.
        public convenience init(path: String) throws(PlaydateError) {
            let pointer = path.withPlaydateCString { videoAPI.loadVideo.unsafelyUnwrapped($0) }
            guard let pointer else {
                throw PlaydateError(message: "unable to load video: \(path)")
            }
            self.init(pointer: pointer, isOwned: true)
        }

        deinit {
            if isOwned {
                videoAPI.freePlayer.unsafelyUnwrapped(pointer)
            }
        }

        /// Sets the bitmap the video renders into.
        public func setContext(_ context: Bitmap) throws(PlaydateError) {
            guard videoAPI.setContext.unsafelyUnwrapped(pointer, context.pointer) != 0 else {
                throw PlaydateError(message: error ?? "unable to set video context")
            }
            retainedContext = context
        }

        /// The bitmap the video renders into.
        public var context: Bitmap? {
            guard let context = videoAPI.getContext.unsafelyUnwrapped(pointer) else { return nil }
            return Bitmap(pointer: context, isOwned: false)
        }

        /// Renders directly into the display framebuffer.
        public func useScreenContext() {
            retainedContext = nil
            videoAPI.useScreenContext.unsafelyUnwrapped(pointer)
        }

        /// Renders frame `frame` into the current context.
        public func renderFrame(_ frame: Int) throws(PlaydateError) {
            guard videoAPI.renderFrame.unsafelyUnwrapped(pointer, Int32(frame)) != 0 else {
                throw PlaydateError(message: error ?? "unable to render frame \(frame)")
            }
        }

        /// The most recent error message, if any.
        public var error: String? {
            String(playdateCString: videoAPI.getError.unsafelyUnwrapped(pointer))
        }

        /// The video's dimensions, frame rate, frame count, and current frame.
        public var info: (width: Int, height: Int, frameRate: Float, frameCount: Int, currentFrame: Int) {
            var width: Int32 = 0, height: Int32 = 0, frameCount: Int32 = 0, currentFrame: Int32 = 0
            var frameRate: Float = 0
            videoAPI.getInfo.unsafelyUnwrapped(pointer, &width, &height, &frameRate,
                                               &frameCount, &currentFrame)
            return (Int(width), Int(height), frameRate, Int(frameCount), Int(currentFrame))
        }
    }

    /// Streams video (and audio) from a file or network connection.
    /// Wraps `LCDStreamPlayer`.
    public final class StreamPlayer {
        let pointer: OpaquePointer
        /// Retains the active source so it outlives the stream.
        private var retainedSource: AnyObject?

        public init() {
            pointer = streamAPI.newPlayer.unsafelyUnwrapped().unsafelyUnwrapped
        }

        deinit {
            streamAPI.freePlayer.unsafelyUnwrapped(pointer)
        }

        /// Sets the sizes of the stream's video and audio buffers, in bytes.
        public func setBufferSize(video: Int, audio: Int) {
            streamAPI.setBufferSize.unsafelyUnwrapped(pointer, Int32(video), Int32(audio))
        }

        /// Streams from an open file.
        public func setFile(_ file: File.Handle) {
            retainedSource = file
            streamAPI.setFile.unsafelyUnwrapped(pointer, file.pointer)
        }

        /// Streams from an HTTP connection.
        public func setHTTPConnection(_ connection: Network.HTTPConnection) {
            retainedSource = connection
            streamAPI.setHTTPConnection.unsafelyUnwrapped(pointer, connection.pointer)
        }

        /// Streams from a TCP connection.
        public func setTCPConnection(_ connection: Network.TCPConnection) {
            retainedSource = connection
            streamAPI.setTCPConnection.unsafelyUnwrapped(pointer, connection.pointer)
        }

        /// The player used for the stream's audio track. Owned by the stream.
        public var filePlayer: Sound.FilePlayer? {
            guard let player = streamAPI.getFilePlayer.unsafelyUnwrapped(pointer) else { return nil }
            return Sound.FilePlayer(pointer: player, isOwned: false)
        }

        /// The player used for the stream's video track. Owned by the stream.
        public var videoPlayer: VideoPlayer? {
            guard let player = streamAPI.getVideoPlayer.unsafelyUnwrapped(pointer) else { return nil }
            return VideoPlayer(pointer: player, isOwned: false)
        }

        /// Advances the stream. Returns `true` if a frame was drawn.
        @discardableResult
        public func update() -> Bool {
            streamAPI.update.unsafelyUnwrapped(pointer)
        }

        /// The number of video frames currently buffered.
        public var bufferedFrameCount: Int {
            Int(streamAPI.getBufferedFrameCount.unsafelyUnwrapped(pointer))
        }

        /// The total number of bytes read from the source.
        public var bytesRead: UInt32 {
            streamAPI.getBytesRead.unsafelyUnwrapped(pointer)
        }
    }
}
