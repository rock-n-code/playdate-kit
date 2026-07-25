internal import CPlaydate

private var videoAPI: UnsafePointer<playdate_video> { Playdate.videoAPI.unsafelyUnwrapped }

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
            let pointer = path.withPlaydateCString { videoAPI.pointee.loadVideo.unsafelyUnwrapped($0) }
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

        /// Sets the bitmap the video renders into.
        public func setContext(_ context: Bitmap) throws(PlaydateError) {
            guard videoAPI.pointee.setContext.unsafelyUnwrapped(pointer, context.pointer) != 0 else {
                throw PlaydateError(message: error ?? "unable to set video context")
            }
            retainedContext = context
        }

        /// The bitmap the video renders into.
        public var context: Bitmap? {
            guard let context = videoAPI.pointee.getContext.unsafelyUnwrapped(pointer) else { return nil }
            return Bitmap(pointer: context, isOwned: false)
        }

        /// Renders directly into the display framebuffer.
        public func useScreenContext() {
            retainedContext = nil
            videoAPI.pointee.useScreenContext.unsafelyUnwrapped(pointer)
        }

        /// Renders frame `frame` into the current context.
        public func renderFrame(_ frame: Int) throws(PlaydateError) {
            guard videoAPI.pointee.renderFrame.unsafelyUnwrapped(pointer, Int32(frame)) != 0 else {
                // Static message: the caller knows the frame it passed, and
                // interpolating it would pull integer formatting machinery
                // into the device binary.
                throw PlaydateError(message: error ?? "unable to render frame")
            }
        }

        /// The most recent error message, if any.
        public var error: String? {
            String(playdateCString: videoAPI.pointee.getError.unsafelyUnwrapped(pointer))
        }

        /// The video's dimensions, frame rate, frame count, and current frame.
        public var info: (width: Int, height: Int, frameRate: Float, frameCount: Int, currentFrame: Int) {
            var width: Int32 = 0, height: Int32 = 0, frameCount: Int32 = 0, currentFrame: Int32 = 0
            var frameRate: Float = 0
            videoAPI.pointee.getInfo.unsafelyUnwrapped(pointer, &width, &height, &frameRate,
                                               &frameCount, &currentFrame)
            return (Int(width), Int(height), frameRate, Int(frameCount), Int(currentFrame))
        }
    }
}
