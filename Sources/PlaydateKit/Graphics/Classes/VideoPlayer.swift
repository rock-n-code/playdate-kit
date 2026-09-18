internal import CPlaydate

/// `playdate->graphics->video`.
private var videoAPI: UnsafePointer<playdate_video> { Playdate.videoAPI.unsafelyUnwrapped }

extension Graphics {
    /// Plays .pdv video files. Wraps `LCDVideoPlayer`.
    public final class VideoPlayer {
        let pointer: OpaquePointer
        /// `false` for players vended by a `StreamPlayer`.
        let isOwned: Bool
        /// The C player holds only a raw pointer to its context.
        private var retainedContext: Bitmap?

        init(pointer: OpaquePointer, isOwned: Bool) {
            self.pointer = pointer
            self.isOwned = isOwned
        }

        public convenience init(path: String) throws(PlaydateError) {
            let pointer = path.withCString { videoAPI.pointee.loadVideo.unsafelyUnwrapped($0) }
            guard let pointer else {
                throw PlaydateError(message: "unable to load video: \(path)")
            }
            self.init(pointer: pointer, isOwned: true)
        }

        deinit {
            if isOwned {
                videoAPI.pointee.freePlayer.unsafelyUnwrapped(pointer)
            }
        }

        /// Retains `context`; throws with `error`. Its mask isn't drawn; use an opaque one.
        public func setContext(_ context: Bitmap) throws(PlaydateError) {
            guard videoAPI.pointee.setContext.unsafelyUnwrapped(pointer, context.pointer) != 0 else {
                throw PlaydateError(message: error ?? "unable to set video context")
            }
            retainedContext = context
        }

        /// Borrowed. If none was set, the player allocates one the size of the video.
        public var context: Bitmap? {
            guard let context = videoAPI.pointee.getContext.unsafelyUnwrapped(pointer) else { return nil }
            return Bitmap(pointer: context, isOwned: false)
        }

        /// Releases any retained context.
        public func useScreenContext() {
            retainedContext = nil
            videoAPI.pointee.useScreenContext.unsafelyUnwrapped(pointer)
        }

        /// Renders into the current context; throws with `error`.
        public func renderFrame(_ frame: Int) throws(PlaydateError) {
            guard videoAPI.pointee.renderFrame.unsafelyUnwrapped(pointer, Int32(frame)) != 0 else {
                // Static: interpolating `frame` would link integer formatting.
                throw PlaydateError(message: error ?? "unable to render frame")
            }
        }

        /// The most recent error message.
        public var error: String? {
            String(playdateCString: videoAPI.pointee.getError.unsafelyUnwrapped(pointer))
        }

        /// Size in pixels, frame rate in frames per second, frame count, current frame.
        public var info: (width: Int, height: Int, frameRate: Float, frameCount: Int, currentFrame: Int) {
            var width: Int32 = 0, height: Int32 = 0, frameCount: Int32 = 0, currentFrame: Int32 = 0
            var frameRate: Float = 0
            videoAPI.pointee.getInfo.unsafelyUnwrapped(pointer, &width, &height, &frameRate,
                                               &frameCount, &currentFrame)
            return (Int(width), Int(height), frameRate, Int(frameCount), Int(currentFrame))
        }
    }
}
