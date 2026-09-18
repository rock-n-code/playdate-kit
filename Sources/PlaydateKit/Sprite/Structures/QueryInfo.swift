internal import CPlaydate

extension Sprite {
    /// A sprite intersected by a line segment. Wraps `SpriteQueryInfo`.
    public struct QueryInfo {
        public let sprite: Sprite
        /// Entry point's position along the segment, 0...1.
        public let ti1: Float
        /// Exit point's position along the segment, 0...1.
        public let ti2: Float
        public let entryPoint: (x: Float, y: Float)
        public let exitPoint: (x: Float, y: Float)

        init(_ info: SpriteQueryInfo) {
            sprite = Sprite.wrapper(for: info.sprite)
            ti1 = info.ti1
            ti2 = info.ti2
            entryPoint = (info.entryPoint.x, info.entryPoint.y)
            exitPoint = (info.exitPoint.x, info.exitPoint.y)
        }
    }
}
