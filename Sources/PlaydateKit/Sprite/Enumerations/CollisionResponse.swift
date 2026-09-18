internal import CPlaydate

extension Sprite {
    /// How a moving sprite reacts to a collision. Wraps `SpriteCollisionResponseType`.
    public enum CollisionResponse: UInt32, Sendable {
        /// Slides along the other sprite.
        case slide = 0
        /// Stops at the point of collision.
        case freeze = 1
        /// Passes through; the collision is still reported.
        case overlap = 2
        case bounce = 3

        /// Unknown C values map to `.freeze`.
        init(_ response: SpriteCollisionResponseType) {
            self = CollisionResponse(rawValue: UInt32(response.rawValue)) ?? .freeze
        }
        var cValue: SpriteCollisionResponseType { SpriteCollisionResponseType(SpriteCollisionResponseType.RawValue(rawValue)) }
    }
}
