internal import CPlaydate

extension Lua {
    /// A handle to a Lua-owned object. Wraps `LuaUDObject`.
    public struct UDObject {
        let pointer: OpaquePointer

        /// Prevents garbage collection until a balancing `release()`. Returns `self`.
        @discardableResult
        public func retain() -> UDObject {
            UDObject(pointer: luaAPI.pointee.retainObject.unsafelyUnwrapped(pointer).unsafelyUnwrapped)
        }

        /// Balances one `retain()`.
        public func release() {
            luaAPI.pointee.releaseObject.unsafelyUnwrapped(pointer)
        }

        /// Sets user-value `slot` (1-based) to the top stack value.
        public func setUserValue(slot: UInt32) {
            luaAPI.pointee.setUserValue.unsafelyUnwrapped(pointer, slot)
        }

        /// Pushes user-value `slot` (1-based); returns its stack position, or `nil` if 0.
        @discardableResult
        public func getUserValue(slot: UInt32) -> Int? {
            let position = luaAPI.pointee.getUserValue.unsafelyUnwrapped(pointer, slot)
            return position == 0 ? nil : Int(position)
        }
    }
}
