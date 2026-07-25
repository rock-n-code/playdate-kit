//
//  Display.swift
//  Wraps `playdate->display` (pd_api_display.h).
//

internal import CPlaydate

/// The display API: resolution, refresh rate, scaling, and effects.
public enum Display {}

extension Display {
    private static var api: UnsafePointer<playdate_display> { Playdate.displayAPI.unsafelyUnwrapped }

    /// The display width in pixels, taking the current scale into account.
    public static var width: Int { Int(api.pointee.getWidth.unsafelyUnwrapped()) }

    /// The display height in pixels, taking the current scale into account.
    public static var height: Int { Int(api.pointee.getHeight.unsafelyUnwrapped()) }

    /// Sets the nominal refresh rate in frames per second. Pass 0 to update
    /// as fast as possible (the update callback drives the pace).
    public static func setRefreshRate(_ rate: Float) {
        api.pointee.setRefreshRate.unsafelyUnwrapped(rate)
    }

    /// The current nominal refresh rate.
    public static var refreshRate: Float { api.pointee.getRefreshRate.unsafelyUnwrapped() }

    /// The measured average frames per second.
    public static var fps: Float { api.pointee.getFPS.unsafelyUnwrapped() }

    /// Draws the frame white-on-black when `true`.
    public static func setInverted(_ inverted: Bool) {
        api.pointee.setInverted.unsafelyUnwrapped(inverted ? 1 : 0)
    }

    /// Sets the display scale factor: 1, 2, 4, or 8.
    public static func setScale(_ scale: UInt32) {
        api.pointee.setScale.unsafelyUnwrapped(scale)
    }

    /// Adds a mosaic effect. Valid values for each axis are 0...3.
    public static func setMosaic(x: UInt32, y: UInt32) {
        api.pointee.setMosaic.unsafelyUnwrapped(x, y)
    }

    /// Flips the display on the given axes.
    public static func setFlipped(x: Bool, y: Bool) {
        api.pointee.setFlipped.unsafelyUnwrapped(x ? 1 : 0, y ? 1 : 0)
    }

    /// Offsets the display by the given amount. Areas outside the frame
    /// buffer draw black.
    public static func setOffset(x: Int, y: Int) {
        api.pointee.setOffset.unsafelyUnwrapped(Int32(x), Int32(y))
    }
}
