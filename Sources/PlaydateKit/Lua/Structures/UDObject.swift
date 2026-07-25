internal import CPlaydate

extension Lua {
    /// A handle to a Lua-owned object. Wraps `LuaUDObject`.
    public struct UDObject {
        let pointer: OpaquePointer

        /// Prevents the object from being garbage-collected until `release()`.
        @discardableResult
        public func retain() -> UDObject {
            UDObject(pointer: luaAPI.pointee.retainObject.unsafelyUnwrapped(pointer).unsafelyUnwrapped)
        }

        /// Balances a `retain()`, allowing the object to be
        /// garbage-collected again.
        public func release() {
            luaAPI.pointee.releaseObject.unsafelyUnwrapped(pointer)
        }

        /// Pops the value on top of the stack and stores it in the object's
        /// user-value `slot` (1-based).
        public func setUserValue(slot: UInt32) {
            luaAPI.pointee.setUserValue.unsafelyUnwrapped(pointer, slot)
        }

        /// Pushes the value in user-value `slot` onto the stack and returns
        /// its stack position, or `nil` if there is none.
        @discardableResult
        public func getUserValue(slot: UInt32) -> Int? {
            let position = luaAPI.pointee.getUserValue.unsafelyUnwrapped(pointer, slot)
            return position == 0 ? nil : Int(position)
        }
    }
}
