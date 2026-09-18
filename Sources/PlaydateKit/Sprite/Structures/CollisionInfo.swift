internal import CPlaydate

extension Sprite {
    /// A single collision. Wraps `SpriteCollisionInfo`.
    public struct CollisionInfo {
        /// The sprite being moved.
        public let sprite: Sprite
        public let other: Sprite
        public let response: CollisionResponse
        /// `true` if already overlapping `other` at the start; `false` if it tunneled through.
        public let overlaps: Bool
        /// Fraction of the move to the goal done at the collision, 0...1.
        public let ti: Float
        /// Difference between the original and actual positions at the collision.
        public let move: (x: Float, y: Float)
        /// Components usually -1, 0, or 1.
        public let normal: (x: Int, y: Int)
        /// Where `sprite` started touching `other`.
        public let touch: (x: Float, y: Float)
        /// `sprite`'s rect at the touch.
        public let spriteRect: Rect
        /// `other`'s rect at the touch.
        public let otherRect: Rect

        init(_ info: SpriteCollisionInfo) {
            sprite = Sprite.wrapper(for: info.sprite)
            other = Sprite.wrapper(for: info.other)
            response = CollisionResponse(info.responseType)
            overlaps = info.overlaps != 0
            ti = info.ti
            move = (info.move.x, info.move.y)
            normal = (Int(info.normal.x), Int(info.normal.y))
            touch = (info.touch.x, info.touch.y)
            spriteRect = Rect(info.spriteRect)
            otherRect = Rect(info.otherRect)
        }
    }
}
