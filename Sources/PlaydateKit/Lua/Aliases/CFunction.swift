public import CPlaydate

extension Lua {
    /// A function callable from Lua. Returns the number of values it pushed
    /// onto the stack.
    public typealias CFunction = lua_CFunction
}
