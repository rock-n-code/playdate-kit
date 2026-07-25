internal import CPlaydate

extension Sound {
    /// A source of audio: the base class of `FilePlayer`, `SamplePlayer`,
    /// `Synth`, `DelayLineTap`, and `CallbackSource`. Wraps `SoundSource`.
    public class Source {
        private static var api: UnsafePointer<playdate_sound_source> { Playdate.sourceAPI.unsafelyUnwrapped }

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
            Source.api.pointee.setVolume.unsafelyUnwrapped(pointer, left, right)
        }

        /// Sets the playback volume of both channels.
        public func setVolume(_ volume: Float) {
            setVolume(left: volume, right: volume)
        }

        /// The playback volume of the left and right channels.
        public var volume: (left: Float, right: Float) {
            var left: Float = 0, right: Float = 0
            Source.api.pointee.getVolume.unsafelyUnwrapped(pointer, &left, &right)
            return (left, right)
        }

        public var isPlaying: Bool {
            Source.api.pointee.isPlaying.unsafelyUnwrapped(pointer) != 0
        }

        /// Sets a function called when the source finishes playing.
        public func setFinishCallback(_ callback: ((Source) -> Void)?) {
            finishCallback = callback
            if callback != nil {
                Source.api.pointee.setFinishCallback.unsafelyUnwrapped(pointer, { _, userdata in
                    guard let userdata else { return }
                    let source = Unmanaged<Source>.fromOpaque(userdata).takeUnretainedValue()
                    source.finishCallback?(source)
                }, Unmanaged.passUnretained(self).toOpaque())
            } else {
                Source.api.pointee.setFinishCallback.unsafelyUnwrapped(pointer, nil, nil)
            }
        }
    }
}
