internal import CPlaydate

/// Display size, refresh rate, scale, and effects. Wraps `playdate_display`.
public enum Display {}

extension Display {
    private static var api: UnsafePointer<playdate_display> { Playdate.displayAPI.unsafelyUnwrapped }

    /// Pixels at the current scale (200 at scale 2).
    public static var width: Int { Int(api.pointee.getWidth.unsafelyUnwrapped()) }

    /// Pixels at the current scale (120 at scale 2).
    public static var height: Int { Int(api.pointee.getHeight.unsafelyUnwrapped()) }

    /// Target frames per second; default 30, max 50. 0 updates as fast as possible.
    public static var refreshRate: Float {
        get { api.pointee.getRefreshRate.unsafelyUnwrapped() }
        set { api.pointee.setRefreshRate.unsafelyUnwrapped(newValue) }
    }

    /// Measured frames per second; can fall below `refreshRate` on slow frames.
    public static var fps: Float { api.pointee.getFPS.unsafelyUnwrapped() }

    /// `true` swaps black and white.
    public static func setInverted(_ inverted: Bool) {
        api.pointee.setInverted.unsafelyUnwrapped(inverted ? 1 : 0)
    }

    /// Valid values: 1, 2, 4, 8.
    public static func setScale(_ scale: UInt32) {
        api.pointee.setScale.unsafelyUnwrapped(scale)
    }

    /// Mosaic effect; `x` and `y` in 0...3.
    public static func setMosaic(x: UInt32, y: UInt32) {
        api.pointee.setMosaic.unsafelyUnwrapped(x, y)
    }

    public static func setFlipped(x: Bool, y: Bool) {
        api.pointee.setFlipped.unsafelyUnwrapped(x ? 1 : 0, y ? 1 : 0)
    }

    /// Offset in pixels; uncovered areas show the current background color.
    public static func setOffset(x: Int, y: Int) {
        api.pointee.setOffset.unsafelyUnwrapped(Int32(x), Int32(y))
    }
}
