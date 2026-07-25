extension Sound {
    /// A source that produces audio by calling back into Swift.
    public final class CallbackSource: Source {
        let callback: Callback

        /// Every callback source is kept alive here while the C side may
        /// still invoke its trampoline: from creation until it is removed
        /// with `Sound.removeSource`/`Channel.removeSource`, or until its
        /// owning channel is freed.
        nonisolated(unsafe) static var live: [CallbackSource] = []

        /// Releases the registration added by `adopt(pointer:)`.
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
}
