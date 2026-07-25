internal import CPlaydate

extension Sprite {
    /// Information about a single collision, mirroring `SpriteCollisionInfo`.
    public struct CollisionInfo {
        /// The sprite being moved.
        public let sprite: Sprite
        /// The sprite it collided with.
        public let other: Sprite
        /// The collision response used.
        public let response: CollisionResponse
        /// `true` if the sprites were overlapping when the collision
        /// started; `false` if the sprite tunneled through.
        public let overlaps: Bool
        /// How far along the movement (0...1) the collision occurred.
        public let ti: Float
        /// The difference between the requested and actual positions.
        public let move: (x: Float, y: Float)
        /// The collision normal (each component -1, 0, or 1).
        public let normal: (x: Int, y: Int)
        /// Where the sprite started touching `other`.
        public let touch: (x: Float, y: Float)
        /// The sprite's rect at the moment of the touch.
        public let spriteRect: Rect
        /// `other`'s rect at the moment of the touch.
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
