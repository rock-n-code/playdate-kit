internal import CPlaydate

extension Graphics {
    /// An integer rectangle mirroring `LCDRect`. `right` and `bottom` are
    /// not inclusive.
    public struct Rect: Sendable {
        public var left: Int
        public var right: Int
        public var top: Int
        public var bottom: Int

        /// Creates a rect from its edges. `right` and `bottom` are not
        /// inclusive.
        public init(left: Int, right: Int, top: Int, bottom: Int) {
            self.left = left
            self.right = right
            self.top = top
            self.bottom = bottom
        }

        /// Creates a rect from an origin and size.
        public init(x: Int, y: Int, width: Int, height: Int) {
            self.init(left: x, right: x + width, top: y, bottom: y + height)
        }

        init(_ rect: LCDRect) {
            self.init(left: Int(rect.left), right: Int(rect.right),
                      top: Int(rect.top), bottom: Int(rect.bottom))
        }

        var cValue: LCDRect {
            LCDRect(left: Int32(left), right: Int32(right),
                    top: Int32(top), bottom: Int32(bottom))
        }

        /// The rect's width.
        public var width: Int { right - left }

        /// The rect's height.
        public var height: Int { bottom - top }

        /// Returns the rect offset by (dx, dy).
        public func translated(dx: Int, dy: Int) -> Rect {
            Rect(left: left + dx, right: right + dx, top: top + dy, bottom: bottom + dy)
        }
    }
}
