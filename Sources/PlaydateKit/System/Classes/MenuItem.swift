internal import CPlaydate

extension System {
    /// An item added to the system menu. Keep no more than three items at once.
    public final class MenuItem {
        let pointer: OpaquePointer
        var onSelect: (MenuItem) -> Void
        /// Retains C strings passed to the OS for option titles.
        private var retainedOptionTitles: [UnsafeMutablePointer<CChar>] = []

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

        /// The menu item's title.
        public var title: String {
            get {
                String(playdateCString: Playdate.systemAPI.pointee.getMenuItemTitle.unsafelyUnwrapped(pointer)) ?? ""
            }
            set {
                newValue.withPlaydateCString {
                    Playdate.systemAPI.pointee.setMenuItemTitle.unsafelyUnwrapped(pointer, $0)
                }
            }
        }

        /// For checkmark items this is 0 or 1; for option items it is the
        /// index of the selected option.
        public var value: Int {
            get { Int(Playdate.systemAPI.pointee.getMenuItemValue.unsafelyUnwrapped(pointer)) }
            set { Playdate.systemAPI.pointee.setMenuItemValue.unsafelyUnwrapped(pointer, Int32(newValue)) }
        }

        /// Convenience view of `value` for checkmark items.
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
