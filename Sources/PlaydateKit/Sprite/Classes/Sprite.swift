internal import CPlaydate

private var spriteAPI: UnsafePointer<playdate_sprite> { Playdate.spriteAPI.unsafelyUnwrapped }

/// A drawable object with position, z-order, and collisions. Wraps `LCDSprite`; static
/// members wrap the global sprite functions. Retains its image, stencil, tilemap, closures.
/// The C userdata slot holds the wrapper back-reference; don't set it from C (use `userdata`).
/// `add()` retains the sprite until `remove()`/`removeAll()`. Owned sprites free their
/// `LCDSprite` on deinit; sprites created elsewhere get transient, non-owning wrappers.
public final class Sprite {
    let pointer: OpaquePointer
    let isOwned: Bool

    /// Index in `displayList`, or -1 when absent; makes `add()`/`remove()` O(1).
    private var displayListIndex = -1

    /// Called by the C trampolines; resources retained so C never points at freed ones.
    var updateFunction: ((Sprite) -> Void)?
    var drawFunction: ((Sprite, _ bounds: Rect, _ drawRect: Rect) -> Void)?
    var collisionResponseFunction: ((Sprite, _ other: Sprite) -> CollisionResponse)?
    private var retainedImage: Graphics.Bitmap?
    private var retainedStencil: Graphics.Bitmap?
    private var retainedTilemap: Graphics.TileMap?

    /// Free-form game storage. Not copied by `copy()`.
    public var userdata: AnyObject?

    init(pointer: OpaquePointer, isOwned: Bool) {
        self.pointer = pointer
        self.isOwned = isOwned
        // Only owned wrappers clear the back-reference in deinit; others would dangle.
        if isOwned {
            spriteAPI.pointee.setUserdata.unsafelyUnwrapped(pointer, Unmanaged.passUnretained(self).toOpaque())
        }
    }

    /// Allocates a sprite, not yet in the display list.
    public convenience init() {
        self.init(pointer: spriteAPI.pointee.newSprite.unsafelyUnwrapped().unsafelyUnwrapped, isOwned: true)
    }

    deinit {
        if isOwned {
            spriteAPI.pointee.setUserdata.unsafelyUnwrapped(pointer, nil)
            spriteAPI.pointee.freeSprite.unsafelyUnwrapped(pointer)
        }
    }

    /// The stored wrapper, or a transient non-owning one for sprites created elsewhere.
    static func wrapper(for pointer: OpaquePointer) -> Sprite {
        if let userdata = spriteAPI.pointee.getUserdata.unsafelyUnwrapped(pointer) {
            return Unmanaged<Sprite>.fromOpaque(userdata).takeUnretainedValue()
        }
        return Sprite(pointer: pointer, isOwned: false)
    }

    /// Also copies callbacks and the retained image, stencil, and tilemap; not `userdata`.
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

    // MARK: - Display list and drawing

    /// Keeps added sprites alive while the C display list references them.
    nonisolated(unsafe) private static var displayList: [Sprite] = []

    /// `true` redraws all sprites every frame; can be faster with many moving sprites.
    public static func setAlwaysRedraw(_ flag: Bool) {
        spriteAPI.pointee.setAlwaysRedraw.unsafelyUnwrapped(flag ? 1 : 0)
    }

    /// Marks `rect` (screen coordinates) dirty. Graphics drawing calls do this already.
    public static func addDirtyRect(_ rect: Graphics.Rect) {
        spriteAPI.pointee.addDirtyRect.unsafelyUnwrapped(rect.cValue)
    }

    public static func drawAll() {
        spriteAPI.pointee.drawSprites.unsafelyUnwrapped()
    }

    /// Calls each sprite's update function, then draws all sprites.
    public static func updateAndDrawAll() {
        spriteAPI.pointee.updateAndDrawSprites.unsafelyUnwrapped()
    }

    /// Number of sprites in the display list.
    public static var count: Int {
        Int(spriteAPI.pointee.getSpriteCount.unsafelyUnwrapped())
    }

    /// Adds to the display list; repeated adds retain only once.
    public func add() {
        spriteAPI.pointee.addSprite.unsafelyUnwrapped(pointer)
        if displayListIndex < 0 {
            displayListIndex = Sprite.displayList.count
            Sprite.displayList.append(self)
        }
    }

    public func remove() {
        spriteAPI.pointee.removeSprite.unsafelyUnwrapped(pointer)
        guard displayListIndex >= 0 else { return }
        // Swap-remove: the keep-alive list is unordered (the OS keeps draw order).
        let index = displayListIndex
        let last = Sprite.displayList.removeLast()
        if last !== self {
            Sprite.displayList[index] = last
            last.displayListIndex = index
        }
        displayListIndex = -1
    }

    public static func remove(_ sprites: [Sprite]) {
        for sprite in sprites { sprite.remove() }
    }

    public static func removeAll() {
        spriteAPI.pointee.removeAllSprites.unsafelyUnwrapped()
        for sprite in displayList { sprite.displayListIndex = -1 }
        displayList = []
    }

    // MARK: - Geometry

    public var bounds: Rect {
        get { Rect(spriteAPI.pointee.getBounds.unsafelyUnwrapped(pointer)) }
        set { spriteAPI.pointee.setBounds.unsafelyUnwrapped(pointer, newValue.cValue) }
    }

    /// Moves so `center` is at (`x`, `y`), recomputing bounds from size and `center`.
    public func moveTo(x: Float, y: Float) {
        spriteAPI.pointee.moveTo.unsafelyUnwrapped(pointer, x, y)
    }

    public func moveBy(dx: Float, dy: Float) {
        spriteAPI.pointee.moveBy.unsafelyUnwrapped(pointer, dx, dy)
    }

    /// Where the sprite's `center` point is.
    public var position: (x: Float, y: Float) {
        var x: Float = 0, y: Float = 0
        spriteAPI.pointee.getPosition.unsafelyUnwrapped(pointer, &x, &y)
        return (x, y)
    }

    /// Size `moveTo(x:y:)` uses to compute bounds.
    public func setSize(width: Float, height: Float) {
        spriteAPI.pointee.setSize.unsafelyUnwrapped(pointer, width, height)
    }

    /// Drawing center as a 0...1 fraction of size; (0, 0) is top left, (1, 1) bottom right.
    /// Default (0.5, 0.5).
    public var center: (x: Float, y: Float) {
        get {
            var x: Float = 0, y: Float = 0
            spriteAPI.pointee.getCenter.unsafelyUnwrapped(pointer, &x, &y)
            return (x, y)
        }
        set { spriteAPI.pointee.setCenter.unsafelyUnwrapped(pointer, newValue.x, newValue.y) }
    }

    /// Higher values draw on top.
    public var zIndex: Int16 {
        get { spriteAPI.pointee.getZIndex.unsafelyUnwrapped(pointer) }
        set { spriteAPI.pointee.setZIndex.unsafelyUnwrapped(pointer, newValue) }
    }

    // MARK: - Appearance

    /// Sets the image, drawn with `flip`, and resizes bounds to match; `nil` removes it.
    public func setImage(_ image: Graphics.Bitmap?, flip: Graphics.BitmapFlip = .unflipped) {
        retainedImage = image
        spriteAPI.pointee.setImage.unsafelyUnwrapped(pointer, image?.pointer, flip.cValue)
    }

    /// The image from `setImage(_:flip:)`, else a non-owning wrapper of the C one, or `nil`.
    public var image: Graphics.Bitmap? {
        if let retainedImage { return retainedImage }
        guard let image = spriteAPI.pointee.getImage.unsafelyUnwrapped(pointer) else { return nil }
        return Graphics.Bitmap(pointer: image, isOwned: false)
    }

    /// The tilemap set here. Setting resizes bounds to match; `nil` removes it.
    public var tilemap: Graphics.TileMap? {
        get { retainedTilemap }
        set {
            retainedTilemap = newValue
            spriteAPI.pointee.setTilemap.unsafelyUnwrapped(pointer, newValue?.pointer)
        }
    }

    public func setDrawMode(_ mode: Graphics.DrawMode) {
        spriteAPI.pointee.setDrawMode.unsafelyUnwrapped(pointer, mode.cValue)
    }

    public var imageFlip: Graphics.BitmapFlip {
        get { Graphics.BitmapFlip(spriteAPI.pointee.getImageFlip.unsafelyUnwrapped(pointer)) }
        set { spriteAPI.pointee.setImageFlip.unsafelyUnwrapped(pointer, newValue.cValue) }
    }

    /// Pixels draw only where `stencil` is white. Screen space: it doesn't move with the
    /// sprite. `nil` clears it. With `tile`, it repeats; width must be a multiple of 32.
    public func setStencil(_ stencil: Graphics.Bitmap?, tile: Bool = false) {
        retainedStencil = stencil
        spriteAPI.pointee.setStencilImage.unsafelyUnwrapped(pointer, stencil?.pointer, tile ? 1 : 0)
    }

    /// Sets an 8×8 stencil pattern, one byte per row.
    public func setStencilPattern(_ rows: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)) {
        // The tuple is 8 contiguous bytes and C copies them, so stack storage is safe.
        withUnsafeBytes(of: rows) { buffer in
            let pattern = UnsafeMutablePointer(
                mutating: buffer.baseAddress.unsafelyUnwrapped.assumingMemoryBound(to: UInt8.self))
            spriteAPI.pointee.setStencilPattern.unsafelyUnwrapped(pointer, pattern)
        }
    }

    /// `InlineArray` overload of the tuple variant.
    @available(macOS 26, *)
    public func setStencilPattern(_ rows: [8 of UInt8]) {
        // C copies the pattern, so passing the inline array's storage is safe.
        rows.span.withUnsafeBufferPointer { buffer in
            spriteAPI.pointee.setStencilPattern.unsafelyUnwrapped(
                pointer, UnsafeMutablePointer(mutating: buffer.baseAddress))
        }
    }

    public func clearStencil() {
        retainedStencil = nil
        spriteAPI.pointee.clearStencil.unsafelyUnwrapped(pointer)
    }

    /// `rect` is in screen coordinates.
    public func setClipRect(_ rect: Graphics.Rect) {
        spriteAPI.pointee.setClipRect.unsafelyUnwrapped(pointer, rect.cValue)
    }

    public func clearClipRect() {
        spriteAPI.pointee.clearClipRect.unsafelyUnwrapped(pointer)
    }

    /// Clips sprites with a z-index in `startZ...endZ` (inclusive) to `rect`.
    public static func setClipRectsInRange(_ rect: Graphics.Rect, startZ: Int, endZ: Int) {
        spriteAPI.pointee.setClipRectsInRange.unsafelyUnwrapped(rect.cValue, Int32(startZ), Int32(endZ))
    }

    /// Clears clip rects of sprites with a z-index in `startZ...endZ` (inclusive).
    public static func clearClipRectsInRange(startZ: Int, endZ: Int) {
        spriteAPI.pointee.clearClipRectsInRange.unsafelyUnwrapped(Int32(startZ), Int32(endZ))
    }

    // MARK: - Flags, redraw, and tag

    /// Whether `updateAndDrawAll()` calls the update function.
    public var updatesEnabled: Bool {
        get { spriteAPI.pointee.updatesEnabled.unsafelyUnwrapped(pointer) != 0 }
        set { spriteAPI.pointee.setUpdatesEnabled.unsafelyUnwrapped(pointer, newValue ? 1 : 0) }
    }

    /// Also requires a `collideRect`. Default `true`.
    public var collisionsEnabled: Bool {
        get { spriteAPI.pointee.collisionsEnabled.unsafelyUnwrapped(pointer) != 0 }
        set { spriteAPI.pointee.setCollisionsEnabled.unsafelyUnwrapped(pointer, newValue ? 1 : 0) }
    }

    public var isVisible: Bool {
        get { spriteAPI.pointee.isVisible.unsafelyUnwrapped(pointer) != 0 }
        set { spriteAPI.pointee.setVisible.unsafelyUnwrapped(pointer, newValue ? 1 : 0) }
    }

    /// Opaque sprites hide what's behind them. Set automatically for images without a mask.
    public func setOpaque(_ flag: Bool) {
        spriteAPI.pointee.setOpaque.unsafelyUnwrapped(pointer, flag ? 1 : 0)
    }

    public func markDirty() {
        spriteAPI.pointee.markDirty.unsafelyUnwrapped(pointer)
    }

    /// `rect` is relative to the sprite's top-left corner.
    public func markDirty(rect: Rect) {
        spriteAPI.pointee.markDirtyRect.unsafelyUnwrapped(pointer, rect.cValue)
    }

    /// Game-defined tag, 0–255, e.g. for collision handling.
    public var tag: UInt8 {
        get { spriteAPI.pointee.getTag.unsafelyUnwrapped(pointer) }
        set { spriteAPI.pointee.setTag.unsafelyUnwrapped(pointer, newValue) }
    }

    /// `true` draws in screen coordinates; collisions stay in world space.
    public func setIgnoresDrawOffset(_ flag: Bool) {
        spriteAPI.pointee.setIgnoresDrawOffset.unsafelyUnwrapped(pointer, flag ? 1 : 0)
    }

    // MARK: - Callbacks

    /// Called by `updateAndDrawAll()`; `nil` removes it.
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

    /// Receives `bounds` and the dirty `drawRect`; `nil` removes it. Runs only while on
    /// screen with a size (from `setSize(width:height:)` or `bounds`).
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

    /// Frees and reallocates the collision data, resetting it. Call when changing scenes.
    public static func resetCollisionWorld() {
        spriteAPI.pointee.resetCollisionWorld.unsafelyUnwrapped()
    }

    /// Relative to the sprite's bounds.
    public var collideRect: Rect {
        get { Rect(spriteAPI.pointee.getCollideRect.unsafelyUnwrapped(pointer)) }
        set { spriteAPI.pointee.setCollideRect.unsafelyUnwrapped(pointer, newValue.cValue) }
    }

    public func clearCollideRect() {
        spriteAPI.pointee.clearCollideRect.unsafelyUnwrapped(pointer)
    }

    /// Chooses this sprite's response when colliding with `other`; `nil` removes it.
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

    /// Visits each entry of a C collision array, then frees it (C transfers ownership).
    private static func visitCollisions(_ pointer: UnsafeMutablePointer<SpriteCollisionInfo>?,
                                        count: Int32, _ visit: (CollisionInfo) -> Void) {
        guard let pointer else { return }
        for index in 0..<Int(count) {
            visit(CollisionInfo(pointer[index]))
        }
        System.systemFree(pointer)
    }

    /// Converts and frees a C collision info array.
    private static func collisionInfos(_ pointer: UnsafeMutablePointer<SpriteCollisionInfo>?,
                                       count: Int32) -> [CollisionInfo] {
        var infos = [CollisionInfo]()
        infos.reserveCapacity(Int(count))
        visitCollisions(pointer, count: count) { infos.append($0) }
        return infos
    }

    /// Where a move toward the goal would end and what it would hit, without moving.
    public func checkCollisions(goalX: Float, goalY: Float)
        -> (actual: (x: Float, y: Float), collisions: [CollisionInfo]) {
        var actualX: Float = 0, actualY: Float = 0, count: Int32 = 0
        let result = spriteAPI.pointee.checkCollisions.unsafelyUnwrapped(
            pointer, goalX, goalY, &actualX, &actualY, &count)
        return ((actualX, actualY), Sprite.collisionInfos(result, count: count))
    }

    /// Like `checkCollisions(goalX:goalY:)`, but visits each collision without allocating.
    public func checkCollisions(goalX: Float, goalY: Float,
                                _ visit: (CollisionInfo) -> Void) -> (x: Float, y: Float) {
        var actualX: Float = 0, actualY: Float = 0, count: Int32 = 0
        let result = spriteAPI.pointee.checkCollisions.unsafelyUnwrapped(
            pointer, goalX, goalY, &actualX, &actualY, &count)
        Sprite.visitCollisions(result, count: count, visit)
        return (actualX, actualY)
    }

    /// Moves toward the goal, resolving collisions. Returns the final position (the goal if
    /// nothing was hit) and the collisions.
    @discardableResult
    public func moveWithCollisions(goalX: Float, goalY: Float)
        -> (actual: (x: Float, y: Float), collisions: [CollisionInfo]) {
        var actualX: Float = 0, actualY: Float = 0, count: Int32 = 0
        let result = spriteAPI.pointee.moveWithCollisions.unsafelyUnwrapped(
            pointer, goalX, goalY, &actualX, &actualY, &count)
        return ((actualX, actualY), Sprite.collisionInfos(result, count: count))
    }

    /// Like `moveWithCollisions(goalX:goalY:)`, but visits collisions without allocating.
    @discardableResult
    public func moveWithCollisions(goalX: Float, goalY: Float,
                                   _ visit: (CollisionInfo) -> Void) -> (x: Float, y: Float) {
        var actualX: Float = 0, actualY: Float = 0, count: Int32 = 0
        let result = spriteAPI.pointee.moveWithCollisions.unsafelyUnwrapped(
            pointer, goalX, goalY, &actualX, &actualY, &count)
        Sprite.visitCollisions(result, count: count, visit)
        return (actualX, actualY)
    }

    /// Visits non-null entries of a C sprite array, then frees it (C transfers ownership).
    private static func visitSprites(_ pointer: UnsafeMutablePointer<OpaquePointer?>?,
                                     count: Int32, _ visit: (Sprite) -> Void) {
        guard let pointer else { return }
        for index in 0..<Int(count) {
            if let spritePointer = pointer[index] {
                visit(wrapper(for: spritePointer))
            }
        }
        System.systemFree(pointer)
    }

    /// Converts and frees a C sprite pointer array.
    private static func sprites(_ pointer: UnsafeMutablePointer<OpaquePointer?>?,
                                count: Int32) -> [Sprite] {
        var sprites = [Sprite]()
        sprites.reserveCapacity(Int(count))
        visitSprites(pointer, count: count) { sprites.append($0) }
        return sprites
    }

    /// Sprites whose collide rects contain (`x`, `y`).
    public static func query(atPoint x: Float, _ y: Float) -> [Sprite] {
        var count: Int32 = 0
        let result = spriteAPI.pointee.querySpritesAtPoint.unsafelyUnwrapped(x, y, &count)
        return sprites(result, count: count)
    }

    /// Like `query(atPoint:_:)`, but visits each sprite without allocating.
    public static func query(atPoint x: Float, _ y: Float, _ visit: (Sprite) -> Void) {
        var count: Int32 = 0
        let result = spriteAPI.pointee.querySpritesAtPoint.unsafelyUnwrapped(x, y, &count)
        visitSprites(result, count: count, visit)
    }

    /// Sprites whose collide rects intersect the `width` × `height` rect at (`x`, `y`).
    public static func query(inRect x: Float, _ y: Float, width: Float, height: Float) -> [Sprite] {
        var count: Int32 = 0
        let result = spriteAPI.pointee.querySpritesInRect.unsafelyUnwrapped(x, y, width, height, &count)
        return sprites(result, count: count)
    }

    /// Like `query(inRect:_:width:height:)`, but visits each sprite without allocating.
    public static func query(inRect x: Float, _ y: Float, width: Float, height: Float,
                             _ visit: (Sprite) -> Void) {
        var count: Int32 = 0
        let result = spriteAPI.pointee.querySpritesInRect.unsafelyUnwrapped(x, y, width, height, &count)
        visitSprites(result, count: count, visit)
    }

    /// Sprites whose collide rects intersect the segment (`x1`, `y1`)–(`x2`, `y2`).
    public static func query(alongLine x1: Float, _ y1: Float, _ x2: Float, _ y2: Float) -> [Sprite] {
        var count: Int32 = 0
        let result = spriteAPI.pointee.querySpritesAlongLine.unsafelyUnwrapped(x1, y1, x2, y2, &count)
        return sprites(result, count: count)
    }

    /// Like `query(alongLine:_:_:_:)`, but visits each sprite without allocating.
    public static func query(alongLine x1: Float, _ y1: Float, _ x2: Float, _ y2: Float,
                             _ visit: (Sprite) -> Void) {
        var count: Int32 = 0
        let result = spriteAPI.pointee.querySpritesAlongLine.unsafelyUnwrapped(x1, y1, x2, y2, &count)
        visitSprites(result, count: count, visit)
    }

    /// Like `query(alongLine:_:_:_:)`, plus entry/exit details. Slower; use only if needed.
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

    /// Sprites whose collide rects overlap this sprite's.
    public var overlappingSprites: [Sprite] {
        var count: Int32 = 0
        let result = spriteAPI.pointee.overlappingSprites.unsafelyUnwrapped(pointer, &count)
        return Sprite.sprites(result, count: count)
    }

    /// Like `overlappingSprites`, but visits each sprite without allocating.
    public func overlappingSprites(_ visit: (Sprite) -> Void) {
        var count: Int32 = 0
        let result = spriteAPI.pointee.overlappingSprites.unsafelyUnwrapped(pointer, &count)
        Sprite.visitSprites(result, count: count, visit)
    }

    /// All overlapping sprites as consecutive pairs: [0] and [1] overlap, [2] and [3], etc.
    public static var allOverlappingSprites: [Sprite] {
        var count: Int32 = 0
        let result = spriteAPI.pointee.allOverlappingSprites.unsafelyUnwrapped(&count)
        return sprites(result, count: count)
    }

    /// Like `allOverlappingSprites`, but visits sprites (same pair order) without allocating.
    public static func allOverlappingSprites(_ visit: (Sprite) -> Void) {
        var count: Int32 = 0
        let result = spriteAPI.pointee.allOverlappingSprites.unsafelyUnwrapped(&count)
        visitSprites(result, count: count, visit)
    }
}
