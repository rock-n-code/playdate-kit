internal import CPlaydate

extension Sound {
    /// Base class of `FilePlayer`, `SamplePlayer`, `Synth`, `DelayLineTap`, and
    /// `CallbackSource`. Wraps `SoundSource`.
    public class Source {
        private static var api: UnsafePointer<playdate_sound_source> { Playdate.sourceAPI.unsafelyUnwrapped }

        /// Set once, right after creation.
        var pointer: OpaquePointer!
        let isOwned: Bool
        var finishCallback: ((Source) -> Void)?

        init(pointer: OpaquePointer?, isOwned: Bool) {
            self.pointer = pointer
            self.isOwned = isOwned
        }

        /// Per-channel volume, 0–1.
        public var volume: (left: Float, right: Float) {
            get {
                var left: Float = 0, right: Float = 0
                Source.api.pointee.getVolume.unsafelyUnwrapped(pointer, &left, &right)
                return (left, right)
            }
            set { Source.api.pointee.setVolume.unsafelyUnwrapped(pointer, newValue.left, newValue.right) }
        }

        public func setVolume(_ volume: Float) {
            self.volume = (volume, volume)
        }

        public var isPlaying: Bool {
            Source.api.pointee.isPlaying.unsafelyUnwrapped(pointer) != 0
        }

        /// Called when the source finishes playing; `nil` removes it.
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
