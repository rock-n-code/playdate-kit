internal import CPlaydate

/// The system API: logging, input, time, menu items, and device state.
public enum System {}

extension System {
    private static var api: UnsafePointer<playdate_sys> { Playdate.systemAPI.unsafelyUnwrapped }

    // MARK: - Memory

    /// The system allocator. Pass `nil` to allocate, `size` 0 to free.
    @discardableResult
    public static func realloc(_ pointer: UnsafeMutableRawPointer?, size: Int) -> UnsafeMutableRawPointer? {
        api.pointee.realloc.unsafelyUnwrapped(pointer, size)
    }

    /// Frees memory that the Playdate OS handed to the caller (e.g. strings
    /// returned by `localizedText(forKey:)`).
    static func systemFree(_ pointer: UnsafeMutableRawPointer?) {
        _ = api.pointee.realloc.unsafelyUnwrapped(pointer, 0)
    }

    // MARK: - Logging

    /// Logs a message to the console (device serial or simulator console).
    public static func log(_ message: String) {
        message.withPlaydateCString { cplaydate_log(Playdate.apiPointer, $0) }
    }

    /// Stops execution and displays the message as a fatal error.
    public static func error(_ message: String) {
        message.withPlaydateCString { cplaydate_error(Playdate.apiPointer, $0) }
    }

    // MARK: - Time

    public static var language: Language { Language(api.pointee.getLanguage.unsafelyUnwrapped()) }

    /// Milliseconds since the game launched. Wraps around after about 49 days.
    public static var currentTimeMilliseconds: UInt32 {
        UInt32(api.pointee.getCurrentTimeMilliseconds.unsafelyUnwrapped())
    }

    /// Seconds (and sub-second milliseconds) since midnight 2000-01-01 UTC.
    public static var secondsSinceEpoch: (seconds: UInt32, milliseconds: UInt32) {
        var milliseconds: UInt32 = 0
        let seconds = withUnsafeMutablePointer(to: &milliseconds) {
            api.pointee.getSecondsSinceEpoch.unsafelyUnwrapped($0)
        }
        return (UInt32(seconds), milliseconds)
    }

    /// High-resolution timer value, in seconds.
    public static var elapsedTime: Float { api.pointee.getElapsedTime.unsafelyUnwrapped() }

    public static func resetElapsedTime() { api.pointee.resetElapsedTime.unsafelyUnwrapped() }

    /// Offset from UTC of the user-set timezone, in seconds.
    public static var timezoneOffset: Int32 { api.pointee.getTimezoneOffset.unsafelyUnwrapped() }

    public static var shouldDisplay24HourTime: Bool {
        api.pointee.shouldDisplay24HourTime.unsafelyUnwrapped() != 0
    }

    public static func convertEpochToDateTime(_ epoch: UInt32) -> DateTime {
        var dateTime = PDDateTime()
        api.pointee.convertEpochToDateTime.unsafelyUnwrapped(epoch, &dateTime)
        return DateTime(dateTime)
    }

    public static func convertDateTimeToEpoch(_ dateTime: DateTime) -> UInt32 {
        var cValue = dateTime.cValue
        return api.pointee.convertDateTimeToEpoch.unsafelyUnwrapped(&cValue)
    }

    /// Blocks execution for the given number of milliseconds.
    public static func delay(milliseconds: UInt32) {
        api.pointee.delay.unsafelyUnwrapped(milliseconds)
    }

    /// Requests the server time. The completion receives the time string or
    /// an error string. Only one request is tracked at a time; a second call
    /// before the first completes replaces the stored completion.
    public static func getServerTime(_ completion: @escaping (_ time: String?, _ error: String?) -> Void) {
        serverTimeCompletion = completion
        api.pointee.getServerTime.unsafelyUnwrapped { time, error in
            let completion = System.serverTimeCompletion
            System.serverTimeCompletion = nil
            completion?(String(playdateCString: time), String(playdateCString: error))
        }
    }

    nonisolated(unsafe) private static var serverTimeCompletion: ((String?, String?) -> Void)?

    // MARK: - Update loop

    /// Sets the per-frame update callback. Return `true` to redraw the display.
    public static func setUpdateCallback(_ callback: @escaping () -> Bool) {
        updateCallback = callback
        api.pointee.setUpdateCallback.unsafelyUnwrapped({ _ in
            System.updateCallback?() == true ? 1 : 0
        }, nil)
    }

    nonisolated(unsafe) private static var updateCallback: (() -> Bool)?

    /// Draws the current frames-per-second value at the given point.
    public static func drawFPS(x: Int = 0, y: Int = 0) {
        api.pointee.drawFPS.unsafelyUnwrapped(Int32(x), Int32(y))
    }

    // MARK: - Input

    /// The current button state: held, pressed this frame, released this frame.
    public static var buttonState: (current: Buttons, pushed: Buttons, released: Buttons) {
        var current = PDButtons(0), pushed = PDButtons(0), released = PDButtons(0)
        api.pointee.getButtonState.unsafelyUnwrapped(&current, &pushed, &released)
        return (Buttons(current), Buttons(pushed), Buttons(released))
    }

    /// Installs a callback invoked for every button press/release. `queueSize`
    /// sets how many events are buffered between frames. The return value of
    /// the callback is reserved by the OS; return 0.
    public static func setButtonCallback(queueSize: Int = 5,
                                         _ callback: ((_ button: Buttons, _ isDown: Bool, _ when: UInt32) -> Int32)?) {
        buttonCallback = callback
        if callback != nil {
            api.pointee.setButtonCallback.unsafelyUnwrapped({ button, down, when, _ in
                System.buttonCallback?(Buttons(button), down != 0, when) ?? 0
            }, nil, Int32(queueSize))
        } else {
            api.pointee.setButtonCallback.unsafelyUnwrapped(nil, nil, Int32(queueSize))
        }
    }

    nonisolated(unsafe) private static var buttonCallback: ((Buttons, Bool, UInt32) -> Int32)?

    public static func setPeripheralsEnabled(_ peripherals: Peripherals) {
        api.pointee.setPeripheralsEnabled.unsafelyUnwrapped(PDPeripherals(PDPeripherals.RawValue(peripherals.rawValue)))
    }

    /// The most recent accelerometer reading, in g. Enable the accelerometer
    /// with `setPeripheralsEnabled(.accelerometer)` first.
    public static var accelerometer: (x: Float, y: Float, z: Float) {
        var x: Float = 0, y: Float = 0, z: Float = 0
        api.pointee.getAccelerometer.unsafelyUnwrapped(&x, &y, &z)
        return (x, y, z)
    }

    /// Degrees the crank moved since the last frame.
    public static var crankChange: Float { api.pointee.getCrankChange.unsafelyUnwrapped() }

    /// The crank position in degrees; 0 points along the +Y axis.
    public static var crankAngle: Float { api.pointee.getCrankAngle.unsafelyUnwrapped() }

    public static var isCrankDocked: Bool { api.pointee.isCrankDocked.unsafelyUnwrapped() != 0 }

    /// Disables or enables the crank dock/undock sounds. Returns the previous setting.
    @discardableResult
    public static func setCrankSoundsDisabled(_ disabled: Bool) -> Bool {
        api.pointee.setCrankSoundsDisabled.unsafelyUnwrapped(disabled ? 1 : 0) != 0
    }

    /// Whether the user has the "flipped" system setting enabled.
    public static var isFlipped: Bool { api.pointee.getFlipped.unsafelyUnwrapped() != 0 }

    public static func setAutoLockDisabled(_ disabled: Bool) {
        api.pointee.setAutoLockDisabled.unsafelyUnwrapped(disabled ? 1 : 0)
    }

    /// Installs a callback invoked when a message is received on the serial port
    /// via `msg <text>`.
    public static func setSerialMessageCallback(_ callback: ((String) -> Void)?) {
        serialMessageCallback = callback
        if callback != nil {
            api.pointee.setSerialMessageCallback.unsafelyUnwrapped { data in
                guard let message = String(playdateCString: data) else { return }
                System.serialMessageCallback?(message)
            }
        } else {
            api.pointee.setSerialMessageCallback.unsafelyUnwrapped(nil)
        }
    }

    nonisolated(unsafe) private static var serialMessageCallback: ((String) -> Void)?

    // MARK: - System menu

    nonisolated(unsafe) private static var liveMenuItems: [MenuItem] = []

    private static let menuItemTrampoline: @convention(c) (UnsafeMutableRawPointer?) -> Void = { userdata in
        guard let userdata else { return }
        let item = Unmanaged<MenuItem>.fromOpaque(userdata).takeUnretainedValue()
        item.onSelect(item)
    }

    /// Adds a plain menu item to the system menu.
    @discardableResult
    public static func addMenuItem(title: String, onSelect: @escaping (MenuItem) -> Void) -> MenuItem? {
        var item: MenuItem?
        title.withPlaydateCString { cTitle in
            let pointer = api.pointee.addMenuItem.unsafelyUnwrapped(cTitle, menuItemTrampoline, nil)
            item = MenuItem(pointer: pointer, onSelect: onSelect)
        }
        return registered(item)
    }

    /// Adds a menu item with a checkbox.
    @discardableResult
    public static func addCheckmarkMenuItem(title: String, isChecked: Bool = false,
                                            onSelect: @escaping (MenuItem) -> Void) -> MenuItem? {
        var item: MenuItem?
        title.withPlaydateCString { cTitle in
            let pointer = api.pointee.addCheckmarkMenuItem.unsafelyUnwrapped(
                cTitle, isChecked ? 1 : 0, menuItemTrampoline, nil)
            item = MenuItem(pointer: pointer, onSelect: onSelect)
        }
        return registered(item)
    }

    /// Adds a menu item that cycles through the given options.
    @discardableResult
    public static func addOptionsMenuItem(title: String, options: [String],
                                          onSelect: @escaping (MenuItem) -> Void) -> MenuItem? {
        // The OS keeps the option title pointers, so copy and retain them for
        // the lifetime of the menu item.
        let copies = options.map { $0.copiedPlaydateCString() }
        var cOptions: [UnsafePointer<CChar>?] = copies.map { UnsafePointer($0) }
        var item: MenuItem?
        title.withPlaydateCString { cTitle in
            cOptions.withUnsafeMutableBufferPointer { buffer in
                let pointer = api.pointee.addOptionsMenuItem.unsafelyUnwrapped(
                    cTitle, buffer.baseAddress, Int32(options.count), menuItemTrampoline, nil)
                item = MenuItem(pointer: pointer, retainedOptionTitles: copies, onSelect: onSelect)
            }
        }
        return registered(item)
    }

    /// Registers the wrapper as the item's userdata and keeps it alive.
    private static func registered(_ item: MenuItem?) -> MenuItem? {
        guard let item else { return nil }
        api.pointee.setMenuItemUserdata.unsafelyUnwrapped(
            item.pointer, Unmanaged.passUnretained(item).toOpaque())
        liveMenuItems.append(item)
        return item
    }

    public static func removeMenuItem(_ item: MenuItem) {
        api.pointee.removeMenuItem.unsafelyUnwrapped(item.pointer)
        item.deallocateRetainedTitles()
        liveMenuItems.removeAll { $0 === item }
    }

    public static func removeAllMenuItems() {
        api.pointee.removeAllMenuItems.unsafelyUnwrapped()
        for item in liveMenuItems { item.deallocateRetainedTitles() }
        liveMenuItems = []
    }

    /// Sets a custom image for the pause menu, optionally shifted left by
    /// `xOffset` (0...200).
    public static func setMenuImage(_ bitmap: Graphics.Bitmap?, xOffset: Int = 0) {
        api.pointee.setMenuImage.unsafelyUnwrapped(bitmap?.pointer, Int32(xOffset))
    }

    // MARK: - Device state

    /// Whether the user has enabled the "reduce flashing" accessibility setting.
    public static var reduceFlashing: Bool { api.pointee.getReduceFlashing.unsafelyUnwrapped() != 0 }

    /// Battery charge, 0...100.
    public static var batteryPercentage: Float { api.pointee.getBatteryPercentage.unsafelyUnwrapped() }

    public static var batteryVoltage: Float { api.pointee.getBatteryVoltage.unsafelyUnwrapped() }

    /// Flushes the CPU instruction cache after loading code at runtime.
    public static func clearICache() { api.pointee.clearICache.unsafelyUnwrapped() }

    /// Quits the current game and restarts it with the given launch arguments.
    public static func restartGame(launchArguments: String? = nil) {
        if let launchArguments {
            launchArguments.withPlaydateCString { api.pointee.restartGame.unsafelyUnwrapped($0) }
        } else {
            api.pointee.restartGame.unsafelyUnwrapped(nil)
        }
    }

    /// The arguments the game was launched with, and the path of the pdx.
    public static var launchArguments: (arguments: String?, path: String?) {
        var path: UnsafePointer<CChar>?
        let arguments = api.pointee.getLaunchArgs.unsafelyUnwrapped(&path)
        return (String(playdateCString: arguments), String(playdateCString: path))
    }

    /// Sends data over the mirror connection. Returns `false` if mirroring is
    /// not active or the send fails.
    @discardableResult
    public static func sendMirrorData(command: UInt8, data: UnsafeMutableRawBufferPointer) -> Bool {
        api.pointee.sendMirrorData.unsafelyUnwrapped(command, data.baseAddress, Int32(data.count))
    }

    /// OS, language, and pdx version information.
    public static var info: Info {
        let info = api.pointee.getSystemInfo.unsafelyUnwrapped().unsafelyUnwrapped.pointee
        return Info(osVersion: info.osversion,
                    language: Language(info.language),
                    pdxVersion: info.pdxversion)
    }

    /// Looks up a localized string by key from the game's strings files.
    public static func localizedText(forKey key: String, language: Language = .system) -> String? {
        key.withPlaydateCString { cKey in
            guard let cString = api.pointee.getLocalizedText.unsafelyUnwrapped(cKey, language.cValue) else {
                return nil
            }
            let text = String(playdateCString: cString)
            systemFree(cString)
            return text
        }
    }

    /// The system volume, 0...1.
    public static var volume: Float { api.pointee.getVolume.unsafelyUnwrapped() }

    public static var powerStatus: PowerStatus {
        PowerStatus(rawValue: UInt32(api.pointee.getPowerStatus.unsafelyUnwrapped().rawValue))
    }

    /// Quits the game and returns to the launcher.
    public static func exitToLauncher() { api.pointee.exitToLauncher.unsafelyUnwrapped() }
}
