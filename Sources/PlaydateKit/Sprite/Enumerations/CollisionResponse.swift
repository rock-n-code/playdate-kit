internal import CPlaydate

extension Sprite {
    /// How a sprite reacts when a collision occurs.
    public enum CollisionResponse: UInt32, Sendable {
        /// The sprite slides along the edge of the other sprite.
        case slide = 0
        /// The sprite stops at the point of collision.
        case freeze = 1
        /// The sprite passes through, still reporting the collision.
        case overlap = 2
        /// The sprite bounces off the other sprite.
        case bounce = 3

        init(_ response: SpriteCollisionResponseType) {
            self = CollisionResponse(rawValue: UInt32(response.rawValue)) ?? .freeze
        }
        var cValue: SpriteCollisionResponseType { SpriteCollisionResponseType(SpriteCollisionResponseType.RawValue(rawValue)) }
    }
}
