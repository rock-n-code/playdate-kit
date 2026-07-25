//
//  Sprite.swift
//  Wraps `playdate->sprite` (pd_api_sprite.h).
//
//  The binding stores a back-reference to each `Sprite` wrapper in the
//  underlying `LCDSprite`'s userdata slot, so callbacks and queries can
//  recover the wrapper. Do not mix these wrappers with C code that sets its
//  own sprite userdata; use `Sprite.userdata` for per-sprite storage instead.
//

internal import CPlaydate

private var spriteAPI: UnsafePointer<playdate_sprite> { Playdate.spriteAPI }

/// A floating-point rectangle mirroring `PDRect`.
public struct Rect: Sendable {
    public var x: Float
    public var y: Float
    public var width: Float
    public var height: Float

    public init(x: Float, y: Float, width: Float, height: Float) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    init(_ rect: PDRect) {
        self.init(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
    }

    var cValue: PDRect { PDRect(x: x, y: y, width: width, height: height) }
}

/// A sprite: a drawable object with position, z-order, and collision
/// support. Wraps `LCDSprite`. Static members wrap the global sprite
/// system functions.
public final class Sprite {
    let pointer: OpaquePointer
    let isOwned: Bool

    /// Per-sprite callbacks and retained resources.
    var updateFunction: ((Sprite) -> Void)?
    var drawFunction: ((Sprite, _ bounds: Rect, _ drawRect: Rect) -> Void)?
    var collisionResponseFunction: ((Sprite, _ other: Sprite) -> CollisionResponse)?
    private var retainedImage: Graphics.Bitmap?
    private var retainedStencil: Graphics.Bitmap?
    private var retainedTilemap: Graphics.TileMap?

    /// Free-form storage for game use (the C userdata slot is reserved
    /// by the binding).
    public var userdata: AnyObject?

    init(pointer: OpaquePointer, isOwned: Bool) {
        self.pointer = pointer
        self.isOwned = isOwned
        spriteAPI.pointee.setUserdata.unsafelyUnwrapped(pointer, Unmanaged.passUnretained(self).toOpaque())
    }

    /// Allocates a new sprite.
    public convenience init() {
        self.init(pointer: spriteAPI.pointee.newSprite.unsafelyUnwrapped().unsafelyUnwrapped, isOwned: true)
    }

    deinit {
        if isOwned {
            spriteAPI.pointee.setUserdata.unsafelyUnwrapped(pointer, nil)
            spriteAPI.pointee.freeSprite.unsafelyUnwrapped(pointer)
        }
    }

    /// Returns the Swift wrapper stored in the sprite's userdata, or a
    /// transient unowned wrapper for sprites created outside the binding.
    static func wrapper(for pointer: OpaquePointer) -> Sprite {
        if let userdata = spriteAPI.pointee.getUserdata.unsafelyUnwrapped(pointer) {
            return Unmanaged<Sprite>.fromOpaque(userdata).takeUnretainedValue()
        }
        return Sprite(pointer: pointer, isOwned: false)
    }

    /// Copies the sprite. Callbacks and retained resources are carried
    /// over to the copy.
    public func copy() -> Sprite {
        let copy = Sprite(pointer: spriteAPI.pointee.copy.unsafelyUnwrapped(pointer).unsafelyUnwrapped,
                          isOwned: true)
        copy.updateFunction = updateFunction
        copy.drawFunction = drawFunction
        copy.collisionResponseFunction = collisionResponseFunction
        copy.retainedImage = retainedImage
        copy.retainedStencil = retainedStencil
        copy.retainedTilemap = retainedTilemap
        return copy
    }

    // MARK: - Types

    /// How a sprite reacts when a collision occurs.
    public enum CollisionResponse: UInt32, Sendable {
        case slide = 0
        case freeze = 1
        case overlap = 2
        case bounce = 3

        init(_ response: SpriteCollisionResponseType) {
            self = CollisionResponse(rawValue: response.rawValue) ?? .freeze
        }
        var cValue: SpriteCollisionResponseType { SpriteCollisionResponseType(rawValue) }
    }

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

    /// Information about a sprite intersected by a line segment,
    /// mirroring `SpriteQueryInfo`.
    public struct QueryInfo {
        public let sprite: Sprite
        /// How far along the segment (0...1) the segment enters the sprite.
        public let ti1: Float
        /// How far along the segment (0...1) the segment exits the sprite.
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

    // MARK: - Display list

    /// Sprites currently added to the display list, kept alive here.
    nonisolated(unsafe) private static var displayList: [Sprite] = []

    /// When `true`, all sprites redraw every frame instead of only when
    /// marked dirty.
    public static func setAlwaysRedraw(_ flag: Bool) {
        spriteAPI.pointee.setAlwaysRedraw.unsafelyUnwrapped(flag ? 1 : 0)
    }

    /// Marks the given screen region as needing a redraw.
    public static func addDirtyRect(_ rect: Graphics.Rect) {
        spriteAPI.pointee.addDirtyRect.unsafelyUnwrapped(rect.cValue)
    }

    /// Draws every sprite in the display list.
    public static func drawAll() {
        spriteAPI.pointee.drawSprites.unsafelyUnwrapped()
    }

    /// Updates and then draws every sprite in the display list.
    public static func updateAndDrawAll() {
        spriteAPI.pointee.updateAndDrawSprites.unsafelyUnwrapped()
    }

    /// The number of sprites in the display list.
    public static var count: Int {
        Int(spriteAPI.pointee.getSpriteCount.unsafelyUnwrapped())
    }

    /// Adds the sprite to the display list.
    public func add() {
        spriteAPI.pointee.addSprite.unsafelyUnwrapped(pointer)
        if !Sprite.displayList.contains(where: { $0 === self }) {
            Sprite.displayList.append(self)
        }
    }

    /// Removes the sprite from the display list.
    public func remove() {
        spriteAPI.pointee.removeSprite.unsafelyUnwrapped(pointer)
        Sprite.displayList.removeAll { $0 === self }
    }

    /// Removes the given sprites from the display list.
    public static func remove(_ sprites: [Sprite]) {
        for sprite in sprites { sprite.remove() }
    }

    /// Removes every sprite from the display list.
    public static func removeAll() {
        spriteAPI.pointee.removeAllSprites.unsafelyUnwrapped()
        displayList = []
    }

    // MARK: - Geometry

    /// The sprite's bounds. Setting this positions and sizes the sprite.
    public var bounds: Rect {
        get { Rect(spriteAPI.pointee.getBounds.unsafelyUnwrapped(pointer)) }
        set { spriteAPI.pointee.setBounds.unsafelyUnwrapped(pointer, newValue.cValue) }
    }

    /// Moves the sprite so its anchor point is at (x, y).
    public func moveTo(x: Float, y: Float) {
        spriteAPI.pointee.moveTo.unsafelyUnwrapped(pointer, x, y)
    }

    /// Moves the sprite by (dx, dy).
    public func moveBy(dx: Float, dy: Float) {
        spriteAPI.pointee.moveBy.unsafelyUnwrapped(pointer, dx, dy)
    }

    /// The sprite's anchor position.
    public var position: (x: Float, y: Float) {
        var x: Float = 0, y: Float = 0
        spriteAPI.pointee.getPosition.unsafelyUnwrapped(pointer, &x, &y)
        return (x, y)
    }

    /// Sets the sprite's size without changing its image.
    public func setSize(width: Float, height: Float) {
        spriteAPI.pointee.setSize.unsafelyUnwrapped(pointer, width, height)
    }

    /// The anchor point used for positioning, where (0, 0) is the top
    /// left and (1, 1) the bottom right. Defaults to (0.5, 0.5).
    public var center: (x: Float, y: Float) {
        get {
            var x: Float = 0, y: Float = 0
            spriteAPI.pointee.getCenter.unsafelyUnwrapped(pointer, &x, &y)
            return (x, y)
        }
        set { spriteAPI.pointee.setCenter.unsafelyUnwrapped(pointer, newValue.x, newValue.y) }
    }

    /// Draw order: higher values draw on top.
    public var zIndex: Int16 {
        get { spriteAPI.pointee.getZIndex.unsafelyUnwrapped(pointer) }
        set { spriteAPI.pointee.setZIndex.unsafelyUnwrapped(pointer, newValue) }
    }

    // MARK: - Appearance

    /// Sets the sprite's image, resizing its bounds to match.
    public func setImage(_ image: Graphics.Bitmap?, flip: Graphics.BitmapFlip = .unflipped) {
        retainedImage = image
        spriteAPI.pointee.setImage.unsafelyUnwrapped(pointer, image?.pointer, flip.cValue)
    }

    /// The sprite's image.
    public var image: Graphics.Bitmap? {
        if let retainedImage { return retainedImage }
        guard let image = spriteAPI.pointee.getImage.unsafelyUnwrapped(pointer) else { return nil }
        return Graphics.Bitmap(pointer: image, isOwned: false)
    }

    /// Sets the sprite's tilemap, resizing its bounds to match.
    public var tilemap: Graphics.TileMap? {
        get { retainedTilemap }
        set {
            retainedTilemap = newValue
            spriteAPI.pointee.setTilemap.unsafelyUnwrapped(pointer, newValue?.pointer)
        }
    }

    /// The mode used to draw the sprite's image.
    public func setDrawMode(_ mode: Graphics.DrawMode) {
        spriteAPI.pointee.setDrawMode.unsafelyUnwrapped(pointer, mode.cValue)
    }

    /// How the sprite's image is mirrored when drawn.
    public var imageFlip: Graphics.BitmapFlip {
        get { Graphics.BitmapFlip(spriteAPI.pointee.getImageFlip.unsafelyUnwrapped(pointer)) }
        set { spriteAPI.pointee.setImageFlip.unsafelyUnwrapped(pointer, newValue.cValue) }
    }

    /// Sets the stencil applied when drawing the sprite. If `tile` is
    /// `true` the image width must be a multiple of 32.
    public func setStencil(_ stencil: Graphics.Bitmap?, tile: Bool = false) {
        retainedStencil = stencil
        spriteAPI.pointee.setStencilImage.unsafelyUnwrapped(pointer, stencil?.pointer, tile ? 1 : 0)
    }

    /// Sets an 8×8 stencil pattern (8 rows of image data).
    public func setStencilPattern(_ rows: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)) {
        var pattern: [UInt8] = [rows.0, rows.1, rows.2, rows.3, rows.4, rows.5, rows.6, rows.7]
        pattern.withUnsafeMutableBufferPointer { buffer in
            spriteAPI.pointee.setStencilPattern.unsafelyUnwrapped(pointer, buffer.baseAddress)
        }
    }

    public func clearStencil() {
        retainedStencil = nil
        spriteAPI.pointee.clearStencil.unsafelyUnwrapped(pointer)
    }

    /// Clips the sprite's drawing to `rect` (screen coordinates).
    public func setClipRect(_ rect: Graphics.Rect) {
        spriteAPI.pointee.setClipRect.unsafelyUnwrapped(pointer, rect.cValue)
    }

    public func clearClipRect() {
        spriteAPI.pointee.clearClipRect.unsafelyUnwrapped(pointer)
    }

    /// Clips all sprites with z-index in `startZ...endZ` to `rect`.
    public static func setClipRectsInRange(_ rect: Graphics.Rect, startZ: Int, endZ: Int) {
        spriteAPI.pointee.setClipRectsInRange.unsafelyUnwrapped(rect.cValue, Int32(startZ), Int32(endZ))
    }

    public static func clearClipRectsInRange(startZ: Int, endZ: Int) {
        spriteAPI.pointee.clearClipRectsInRange.unsafelyUnwrapped(Int32(startZ), Int32(endZ))
    }

    // MARK: - Behavior flags

    /// Whether the sprite's update function is called by `updateAndDrawAll()`.
    public var updatesEnabled: Bool {
        get { spriteAPI.pointee.updatesEnabled.unsafelyUnwrapped(pointer) != 0 }
        set { spriteAPI.pointee.setUpdatesEnabled.unsafelyUnwrapped(pointer, newValue ? 1 : 0) }
    }

    public var collisionsEnabled: Bool {
        get { spriteAPI.pointee.collisionsEnabled.unsafelyUnwrapped(pointer) != 0 }
        set { spriteAPI.pointee.setCollisionsEnabled.unsafelyUnwrapped(pointer, newValue ? 1 : 0) }
    }

    public var isVisible: Bool {
        get { spriteAPI.pointee.isVisible.unsafelyUnwrapped(pointer) != 0 }
        set { spriteAPI.pointee.setVisible.unsafelyUnwrapped(pointer, newValue ? 1 : 0) }
    }

    /// Marking a sprite opaque tells the system it does not need to redraw
    /// anything behind it.
    public func setOpaque(_ flag: Bool) {
        spriteAPI.pointee.setOpaque.unsafelyUnwrapped(pointer, flag ? 1 : 0)
    }

    /// Forces the sprite to redraw this frame.
    public func markDirty() {
        spriteAPI.pointee.markDirty.unsafelyUnwrapped(pointer)
    }

    /// Marks part of the sprite (in sprite-local coordinates) as needing
    /// a redraw.
    public func markDirty(rect: Rect) {
        spriteAPI.pointee.markDirtyRect.unsafelyUnwrapped(pointer, rect.cValue)
    }

    /// An integer tag for identifying sprites (e.g. in collisions).
    public var tag: UInt8 {
        get { spriteAPI.pointee.getTag.unsafelyUnwrapped(pointer) }
        set { spriteAPI.pointee.setTag.unsafelyUnwrapped(pointer, newValue) }
    }

    /// When `true`, the sprite draws in screen coordinates, ignoring the
    /// global draw offset.
    public func setIgnoresDrawOffset(_ flag: Bool) {
        spriteAPI.pointee.setIgnoresDrawOffset.unsafelyUnwrapped(pointer, flag ? 1 : 0)
    }

    // MARK: - Callbacks

    /// Sets the function called by `updateAndDrawAll()` for this sprite.
    public func setUpdateFunction(_ update: ((Sprite) -> Void)?) {
        updateFunction = update
        if update != nil {
            spriteAPI.pointee.setUpdateFunction.unsafelyUnwrapped(pointer, { spritePointer in
                guard let spritePointer else { return }
                let sprite = Sprite.wrapper(for: spritePointer)
                sprite.updateFunction?(sprite)
            })
        } else {
            spriteAPI.pointee.setUpdateFunction.unsafelyUnwrapped(pointer, nil)
        }
    }

    /// Sets a custom draw function, called when the sprite needs to draw.
    /// `bounds` is the sprite's bounds; `drawRect` is the region that
    /// needs redrawing.
    public func setDrawFunction(_ draw: ((Sprite, _ bounds: Rect, _ drawRect: Rect) -> Void)?) {
        drawFunction = draw
        if draw != nil {
            spriteAPI.pointee.setDrawFunction.unsafelyUnwrapped(pointer, { spritePointer, bounds, drawRect in
                guard let spritePointer else { return }
                let sprite = Sprite.wrapper(for: spritePointer)
                sprite.drawFunction?(sprite, Rect(bounds), Rect(drawRect))
            })
        } else {
            spriteAPI.pointee.setDrawFunction.unsafelyUnwrapped(pointer, nil)
        }
    }

    // MARK: - Collisions

    /// Clears the collision world. Call when changing scenes.
    public static func resetCollisionWorld() {
        spriteAPI.pointee.resetCollisionWorld.unsafelyUnwrapped()
    }

    /// The rect (in sprite-local coordinates) used for collisions.
    public var collideRect: Rect {
        get { Rect(spriteAPI.pointee.getCollideRect.unsafelyUnwrapped(pointer)) }
        set { spriteAPI.pointee.setCollideRect.unsafelyUnwrapped(pointer, newValue.cValue) }
    }

    public func clearCollideRect() {
        spriteAPI.pointee.clearCollideRect.unsafelyUnwrapped(pointer)
    }

    /// Sets the function deciding how this sprite responds when it
    /// collides with `other`.
    public func setCollisionResponseFunction(_ filter: ((Sprite, _ other: Sprite) -> CollisionResponse)?) {
        collisionResponseFunction = filter
        if filter != nil {
            spriteAPI.pointee.setCollisionResponseFunction.unsafelyUnwrapped(pointer, { spritePointer, otherPointer in
                guard let spritePointer, let otherPointer else { return kCollisionTypeFreeze }
                let sprite = Sprite.wrapper(for: spritePointer)
                let other = Sprite.wrapper(for: otherPointer)
                return sprite.collisionResponseFunction?(sprite, other).cValue ?? kCollisionTypeFreeze
            })
        } else {
            spriteAPI.pointee.setCollisionResponseFunction.unsafelyUnwrapped(pointer, nil)
        }
    }

    /// Converts and frees a C collision info array.
    private static func collisionInfos(_ pointer: UnsafeMutablePointer<SpriteCollisionInfo>?,
                                       count: Int32) -> [CollisionInfo] {
        guard let pointer else { return [] }
        var infos = [CollisionInfo]()
        infos.reserveCapacity(Int(count))
        for index in 0..<Int(count) {
            infos.append(CollisionInfo(pointer[index]))
        }
        System.systemFree(pointer)
        return infos
    }

    /// Returns the collisions that would occur if the sprite moved toward
    /// (goalX, goalY), without moving it.
    public func checkCollisions(goalX: Float, goalY: Float)
        -> (actual: (x: Float, y: Float), collisions: [CollisionInfo]) {
        var actualX: Float = 0, actualY: Float = 0, count: Int32 = 0
        let result = spriteAPI.pointee.checkCollisions.unsafelyUnwrapped(
            pointer, goalX, goalY, &actualX, &actualY, &count)
        return ((actualX, actualY), Sprite.collisionInfos(result, count: count))
    }

    /// Moves the sprite toward (goalX, goalY), resolving collisions, and
    /// returns where it ended up and what it hit.
    @discardableResult
    public func moveWithCollisions(goalX: Float, goalY: Float)
        -> (actual: (x: Float, y: Float), collisions: [CollisionInfo]) {
        var actualX: Float = 0, actualY: Float = 0, count: Int32 = 0
        let result = spriteAPI.pointee.moveWithCollisions.unsafelyUnwrapped(
            pointer, goalX, goalY, &actualX, &actualY, &count)
        return ((actualX, actualY), Sprite.collisionInfos(result, count: count))
    }

    /// Converts and frees a C sprite pointer array.
    private static func sprites(_ pointer: UnsafeMutablePointer<OpaquePointer?>?,
                                count: Int32) -> [Sprite] {
        guard let pointer else { return [] }
        var sprites = [Sprite]()
        sprites.reserveCapacity(Int(count))
        for index in 0..<Int(count) {
            if let spritePointer = pointer[index] {
                sprites.append(wrapper(for: spritePointer))
            }
        }
        System.systemFree(pointer)
        return sprites
    }

    /// Sprites with collision rects containing the point.
    public static func query(atPoint x: Float, _ y: Float) -> [Sprite] {
        var count: Int32 = 0
        let result = spriteAPI.pointee.querySpritesAtPoint.unsafelyUnwrapped(x, y, &count)
        return sprites(result, count: count)
    }

    /// Sprites with collision rects intersecting the rect.
    public static func query(inRect x: Float, _ y: Float, width: Float, height: Float) -> [Sprite] {
        var count: Int32 = 0
        let result = spriteAPI.pointee.querySpritesInRect.unsafelyUnwrapped(x, y, width, height, &count)
        return sprites(result, count: count)
    }

    /// Sprites with collision rects intersecting the line segment.
    public static func query(alongLine x1: Float, _ y1: Float, _ x2: Float, _ y2: Float) -> [Sprite] {
        var count: Int32 = 0
        let result = spriteAPI.pointee.querySpritesAlongLine.unsafelyUnwrapped(x1, y1, x2, y2, &count)
        return sprites(result, count: count)
    }

    /// Like `query(alongLine:)`, with entry/exit information for each sprite.
    public static func queryInfo(alongLine x1: Float, _ y1: Float,
                                 _ x2: Float, _ y2: Float) -> [QueryInfo] {
        var count: Int32 = 0
        guard let result = spriteAPI.pointee.querySpriteInfoAlongLine.unsafelyUnwrapped(
            x1, y1, x2, y2, &count) else { return [] }
        var infos = [QueryInfo]()
        infos.reserveCapacity(Int(count))
        for index in 0..<Int(count) {
            infos.append(QueryInfo(result[index]))
        }
        System.systemFree(result)
        return infos
    }

    /// Sprites whose collision rects overlap this sprite's.
    public var overlappingSprites: [Sprite] {
        var count: Int32 = 0
        let result = spriteAPI.pointee.overlappingSprites.unsafelyUnwrapped(pointer, &count)
        return Sprite.sprites(result, count: count)
    }

    /// All sprites in the display list that overlap another sprite.
    public static var allOverlappingSprites: [Sprite] {
        var count: Int32 = 0
        let result = spriteAPI.pointee.allOverlappingSprites.unsafelyUnwrapped(&count)
        return sprites(result, count: count)
    }
}
