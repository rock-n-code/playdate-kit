public import CPlaydate

extension Lua {
    /// Wraps `lua_CFunction`; returns the number of values it pushed as results.
    public typealias CFunction = lua_CFunction
}
