extension Sound {
    /// A source rendered by a Swift callback every audio cycle. Create with
    /// `Sound.addSource(stereo:_:)`; it stays alive until removed with `removeSource`.
    public final class CallbackSource: Source {
        let callback: Callback

        /// Keeps sources alive for the C trampoline until removed (`Sound`/`Channel`
        /// `.removeSource`) or their channel is freed.
        nonisolated(unsafe) static var live: [CallbackSource] = []

        /// Drops the reference added by `adopt(pointer:)`.
        static func release(_ source: Source) {
            live.removeAll { $0 === source }
        }

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
            var leftSpan = UnsafeMutableBufferPointer(start: left, count: Int(length)).mutableSpan
            var rightSpan = UnsafeMutableBufferPointer(start: right, count: right == nil ? 0 : Int(length)).mutableSpan
            return source.callback(&leftSpan, &rightSpan) ? 1 : 0
        }

        /// Attaches the C object created for this source.
        func adopt(pointer: OpaquePointer) {
            self.pointer = pointer
            CallbackSource.live.append(self)
        }
    }
}
