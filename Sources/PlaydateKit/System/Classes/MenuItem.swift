internal import CPlaydate

extension System {
    /// A custom system menu item (at most three). Wraps `PDMenuItem`.
    /// `System` keeps it alive until it is removed.
    public final class MenuItem {
        let pointer: OpaquePointer
        var onSelect: (MenuItem) -> Void
        /// Option title C strings the OS points into; freed on removal.
        private var retainedOptionTitles: [UnsafeMutablePointer<CChar>] = []

        /// Fails, freeing `retainedOptionTitles`, if `pointer` is `nil`.
        init?(pointer: OpaquePointer?,
              retainedOptionTitles: [UnsafeMutablePointer<CChar>] = [],
              onSelect: @escaping (MenuItem) -> Void) {
            guard let pointer else {
                for title in retainedOptionTitles { title.deallocate() }
                return nil
            }
            self.pointer = pointer
            self.retainedOptionTitles = retainedOptionTitles
            self.onSelect = onSelect
        }

        /// The displayed title; empty if the OS returns none.
        public var title: String {
            get {
                String(playdateCString: Playdate.systemAPI.pointee.getMenuItemTitle.unsafelyUnwrapped(pointer)) ?? ""
            }
            set {
                newValue.withCString {
                    Playdate.systemAPI.pointee.setMenuItemTitle.unsafelyUnwrapped(pointer, $0)
                }
            }
        }

        /// Checkmark items: 0 or 1 (checked). Options items: the selected index.
        public var value: Int {
            get { Int(Playdate.systemAPI.pointee.getMenuItemValue.unsafelyUnwrapped(pointer)) }
            set { Playdate.systemAPI.pointee.setMenuItemValue.unsafelyUnwrapped(pointer, Int32(newValue)) }
        }

        /// `value` as a `Bool`, for checkmark items.
        public var isChecked: Bool {
            get { value != 0 }
            set { value = newValue ? 1 : 0 }
        }

        func deallocateRetainedTitles() {
            for title in retainedOptionTitles { title.deallocate() }
            retainedOptionTitles = []
        }
    }
}
