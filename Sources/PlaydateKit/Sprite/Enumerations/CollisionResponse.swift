internal import CPlaydate

extension Sprite {
    /// How a sprite reacts when a collision occurs.
    public enum CollisionResponse: UInt32, Sendable {
        case slide = 0
        case freeze = 1
        case overlap = 2
        case bounce = 3

        init(_ response: SpriteCollisionResponseType) {
            self = CollisionResponse(rawValue: UInt32(response.rawValue)) ?? .freeze
        }
        var cValue: SpriteCollisionResponseType { SpriteCollisionResponseType(SpriteCollisionResponseType.RawValue(rawValue)) }
    }
}
