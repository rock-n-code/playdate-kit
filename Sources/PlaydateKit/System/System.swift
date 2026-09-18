internal import CPlaydate

/// The system API: logging, input, time, menu items, and device state.
public enum System {}

extension System {
    /// Cached `playdate->system` table.
    private static var api: UnsafePointer<playdate_sys> { Playdate.systemAPI.unsafelyUnwrapped }

    // MARK: - Memory

    /// System allocator (`realloc` semantics): `nil` allocates; `size` 0 frees, returns `nil`.
    @discardableResult
    public static func realloc(_ pointer: UnsafeMutableRawPointer?, size: Int) -> UnsafeMutableRawPointer? {
        api.pointee.realloc.unsafelyUnwrapped(pointer, size)
    }

    /// Frees OS-allocated memory, e.g. `localizedText(forKey:language:)` strings.
    static func systemFree(_ pointer: UnsafeMutableRawPointer?) {
        _ = api.pointee.realloc.unsafelyUnwrapped(pointer, 0)
    }

    // MARK: - Logging

    /// Logs to the device serial or simulator console.
    public static func log(_ message: String) {
        message.withCString { cplaydate_log(Playdate.apiPointer, $0) }
    }

    /// Logs `message` as an error, then pauses execution.
    public static func error(_ message: String) {
        message.withCString { cplaydate_error(Playdate.apiPointer, $0) }
    }

    // MARK: - Language and time

    public static var language: Language { Language(api.pointee.getLanguage.unsafelyUnwrapped()) }

    /// Milliseconds since an arbitrary point; pauses while asleep; wraps after ~49 days.
    public static var currentTimeMilliseconds: UInt32 {
        UInt32(api.pointee.getCurrentTimeMilliseconds.unsafelyUnwrapped())
    }

    /// Seconds, plus millisecond remainder, since 2000-01-01 00:00 UTC.
    public static var secondsSinceEpoch: (seconds: UInt32, milliseconds: UInt32) {
        var milliseconds: UInt32 = 0
        let seconds = withUnsafeMutablePointer(to: &milliseconds) {
            api.pointee.getSecondsSinceEpoch.unsafelyUnwrapped($0)
        }
        return (UInt32(seconds), milliseconds)
    }

    /// Seconds since `resetElapsedTime()`, with microsecond accuracy.
    public static var elapsedTime: Float { api.pointee.getElapsedTime.unsafelyUnwrapped() }

    public static func resetElapsedTime() { api.pointee.resetElapsedTime.unsafelyUnwrapped() }

    /// Offset from UTC, in seconds.
    public static var timezoneOffset: Int32 { api.pointee.getTimezoneOffset.unsafelyUnwrapped() }

    /// The user's 24-hour time setting.
    public static var shouldDisplay24HourTime: Bool {
        api.pointee.shouldDisplay24HourTime.unsafelyUnwrapped() != 0
    }

    /// `epoch` is seconds since 2000-01-01.
    public static func convertEpochToDateTime(_ epoch: UInt32) -> DateTime {
        var dateTime = PDDateTime()
        api.pointee.convertEpochToDateTime.unsafelyUnwrapped(epoch, &dateTime)
        return DateTime(dateTime)
    }

    /// Returns seconds since 2000-01-01.
    public static func convertDateTimeToEpoch(_ dateTime: DateTime) -> UInt32 {
        var cValue = dateTime.cValue
        return api.pointee.convertDateTimeToEpoch.unsafelyUnwrapped(&cValue)
    }

    /// Blocks execution.
    public static func delay(milliseconds: UInt32) {
        api.pointee.delay.unsafelyUnwrapped(milliseconds)
    }

    /// Asynchronously fetches the server time: `time` is seconds since 2000-01-01 UTC,
    /// as a string. One completion at a time; calling again replaces a pending one.
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

    /// Sets the per-frame callback, replacing any previous one; return `true` to redraw.
    public static func setUpdateCallback(_ callback: @escaping () -> Bool) {
        updateCallback = callback
        api.pointee.setUpdateCallback.unsafelyUnwrapped({ _ in
            System.updateCallback?() == true ? 1 : 0
        }, nil)
    }

    nonisolated(unsafe) private static var updateCallback: (() -> Bool)?

    /// Draws the current FPS at (`x`, `y`).
    public static func drawFPS(x: Int = 0, y: Int = 0) {
        api.pointee.drawFPS.unsafelyUnwrapped(Int32(x), Int32(y))
    }

    // MARK: - Input

    /// Buttons held now, and those pushed or released during the previous update.
    public static var buttonState: (current: Buttons, pushed: Buttons, released: Buttons) {
        var current = PDButtons(0), pushed = PDButtons(0), released = PDButtons(0)
        api.pointee.getButtonState.unsafelyUnwrapped(&current, &pushed, &released)
        return (Buttons(current), Buttons(pushed), Buttons(released))
    }

    /// Calls `callback` per button down/up in the previous update, replacing any previous
    /// one; `nil` removes it. `queueSize`: events buffered per update (5 suffices at 30 FPS).
    /// `callback` returns 0, or non-zero to signal an error.
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

    /// Enables `peripherals`, disabling the rest; accelerometer data arrives next update.
    public static func setPeripheralsEnabled(_ peripherals: Peripherals) {
        api.pointee.setPeripheralsEnabled.unsafelyUnwrapped(PDPeripherals(PDPeripherals.RawValue(peripherals.rawValue)))
    }

    /// Last reading, in g; requires `setPeripheralsEnabled(.accelerometer)`.
    public static var accelerometer: (x: Float, y: Float, z: Float) {
        var x: Float = 0, y: Float = 0, z: Float = 0
        api.pointee.getAccelerometer.unsafelyUnwrapped(&x, &y, &z)
        return (x, y, z)
    }

    /// Degrees moved since last read; negative is counterclockwise.
    public static var crankChange: Float { api.pointee.getCrankChange.unsafelyUnwrapped() }

    /// Degrees, 0...360; 0 points up, increasing clockwise viewed from the right side.
    public static var crankAngle: Float { api.pointee.getCrankAngle.unsafelyUnwrapped() }

    public static var isCrankDocked: Bool { api.pointee.isCrankDocked.unsafelyUnwrapped() != 0 }

    /// Toggles crank dock/undock sounds; returns the previous `disabled` value.
    @discardableResult
    public static func setCrankSoundsDisabled(_ disabled: Bool) -> Bool {
        api.pointee.setCrankSoundsDisabled.unsafelyUnwrapped(disabled ? 1 : 0) != 0
    }

    /// The user's "flipped" system setting.
    public static var isFlipped: Bool { api.pointee.getFlipped.unsafelyUnwrapped() != 0 }

    /// Toggles the 3-minute auto lock; either call resets its timer.
    public static func setAutoLockDisabled(_ disabled: Bool) {
        api.pointee.setAutoLockDisabled.unsafelyUnwrapped(disabled ? 1 : 0)
    }

    /// Calls `callback` for serial `msg <text>` messages; `nil` removes it. One closure
    /// at a time.
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

    // Retains items until removed; the OS holds only unretained userdata pointers.
    nonisolated(unsafe) private static var liveMenuItems: [MenuItem] = []

    private static let menuItemTrampoline: @convention(c) (UnsafeMutableRawPointer?) -> Void = { userdata in
        guard let userdata else { return }
        let item = Unmanaged<MenuItem>.fromOpaque(userdata).takeUnretainedValue()
        item.onSelect(item)
    }

    /// Adds an action item; `onSelect` runs when picked. `nil` if the OS can't add it.
    @discardableResult
    public static func addMenuItem(title: String, onSelect: @escaping (MenuItem) -> Void) -> MenuItem? {
        var item: MenuItem?
        title.withCString { cTitle in
            let pointer = api.pointee.addMenuItem.unsafelyUnwrapped(cTitle, menuItemTrampoline, nil)
            item = MenuItem(pointer: pointer, onSelect: onSelect)
        }
        return registered(item)
    }

    /// Adds a checkmark item; `onSelect` runs when the menu closes after a toggle.
    /// `nil` if the OS can't add it.
    @discardableResult
    public static func addCheckmarkMenuItem(title: String, isChecked: Bool = false,
                                            onSelect: @escaping (MenuItem) -> Void) -> MenuItem? {
        var item: MenuItem?
        title.withCString { cTitle in
            let pointer = api.pointee.addCheckmarkMenuItem.unsafelyUnwrapped(
                cTitle, isChecked ? 1 : 0, menuItemTrampoline, nil)
            item = MenuItem(pointer: pointer, onSelect: onSelect)
        }
        return registered(item)
    }

    /// Adds an item cycling through `options`; `onSelect` runs when the menu closes
    /// after a change. `nil` if the OS can't add it.
    @discardableResult
    public static func addOptionsMenuItem(title: String, options: [String],
                                          onSelect: @escaping (MenuItem) -> Void) -> MenuItem? {
        // The OS keeps the title pointers; the copies live until the item is removed.
        let copies = options.map { $0.copiedPlaydateCString() }
        var cOptions: [UnsafePointer<CChar>?] = copies.map { UnsafePointer($0) }
        var item: MenuItem?
        title.withCString { cTitle in
            cOptions.withUnsafeMutableBufferPointer { buffer in
                let pointer = api.pointee.addOptionsMenuItem.unsafelyUnwrapped(
                    cTitle, buffer.baseAddress, Int32(options.count), menuItemTrampoline, nil)
                item = MenuItem(pointer: pointer, retainedOptionTitles: copies, onSelect: onSelect)
            }
        }
        return registered(item)
    }

    /// Sets `item` as its own userdata and retains it until removed.
    private static func registered(_ item: MenuItem?) -> MenuItem? {
        guard let item else { return nil }
        api.pointee.setMenuItemUserdata.unsafelyUnwrapped(
            item.pointer, Unmanaged.passUnretained(item).toOpaque())
        liveMenuItems.append(item)
        return item
    }

    /// Removes `item`; the OS frees it, so don't use `item` afterwards.
    public static func removeMenuItem(_ item: MenuItem) {
        api.pointee.removeMenuItem.unsafelyUnwrapped(item.pointer)
        item.deallocateRetainedTitles()
        liveMenuItems.removeAll { $0 === item }
    }

    /// Removes all custom items; existing `MenuItem`s must not be used afterwards.
    public static func removeAllMenuItems() {
        api.pointee.removeAllMenuItems.unsafelyUnwrapped()
        for item in liveMenuItems { item.deallocateRetainedTitles() }
        liveMenuItems = []
    }

    /// Sets the 400x240 menu image; only its left 200 px stay visible. `xOffset`
    /// (0...200 px) shifts it left as the menu animates in.
    public static func setMenuImage(_ bitmap: Graphics.Bitmap?, xOffset: Int = 0) {
        api.pointee.setMenuImage.unsafelyUnwrapped(bitmap?.pointer, Int32(xOffset))
    }

    // MARK: - Device state

    /// The user's "reduce flashing" accessibility setting.
    public static var reduceFlashing: Bool { api.pointee.getReduceFlashing.unsafelyUnwrapped() != 0 }

    /// 0 (empty)...100 (full).
    public static var batteryPercentage: Float { api.pointee.getBatteryPercentage.unsafelyUnwrapped() }

    /// In volts.
    public static var batteryVoltage: Float { api.pointee.getBatteryVoltage.unsafelyUnwrapped() }

    /// Flushes the CPU instruction cache; needed only after modifying code at runtime.
    public static func clearICache() { api.pointee.clearICache.unsafelyUnwrapped() }

    /// Reinitializes the runtime and restarts the game with `launchArguments`.
    public static func restartGame(launchArguments: String? = nil) {
        if let launchArguments {
            launchArguments.withCString { api.pointee.restartGame.unsafelyUnwrapped($0) }
        } else {
            api.pointee.restartGame.unsafelyUnwrapped(nil)
        }
    }

    /// Launch arguments (simulator command line, device `run`, or `restartGame`) and
    /// the loaded game's path.
    public static var launchArguments: (arguments: String?, path: String?) {
        var path: UnsafePointer<CChar>?
        let arguments = api.pointee.getLaunchArgs.unsafelyUnwrapped(&path)
        return (String(playdateCString: arguments), String(playdateCString: path))
    }

    /// Sends `data` with `command` over Mirror; `false` if not mirroring or the send fails.
    @discardableResult
    public static func sendMirrorData(command: UInt8, data: Span<UInt8>) -> Bool {
        data.withUnsafeBufferPointer { buffer in
            // The C API takes a non-const pointer but only reads the data.
            api.pointee.sendMirrorData.unsafelyUnwrapped(
                command, UnsafeMutableRawPointer(mutating: buffer.baseAddress), Int32(buffer.count))
        }
    }

    /// OS version, system language, and the SDK version the game was built with.
    public static var info: Info {
        let info = api.pointee.getSystemInfo.unsafelyUnwrapped().unsafelyUnwrapped.pointee
        return Info(osVersion: info.osversion,
                    language: Language(info.language),
                    pdxVersion: info.pdxversion)
    }

    /// Looks up `key` in `language`'s `.strings` file; `nil` if the key or file is missing.
    /// `.system` falls back to the other language's file if the system one can't load.
    public static func localizedText(forKey key: String, language: Language = .system) -> String? {
        key.withCString { cKey in
            guard let cString = api.pointee.getLocalizedText.unsafelyUnwrapped(cKey, language.cValue) else {
                return nil
            }
            let text = String(playdateCString: cString)
            systemFree(cString)
            return text
        }
    }

    /// Menu volume, 0...1.
    public static var volume: Float { api.pointee.getVolume.unsafelyUnwrapped() }

    public static var powerStatus: PowerStatus {
        PowerStatus(rawValue: UInt32(api.pointee.getPowerStatus.unsafelyUnwrapped().rawValue))
    }

    /// Sends the game `kEventTerminate`, then quits to the launcher.
    public static func exitToLauncher() { api.pointee.exitToLauncher.unsafelyUnwrapped() }
}
