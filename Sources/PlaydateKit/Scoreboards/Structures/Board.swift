internal import CPlaydate

extension Scoreboards {
    /// One of the game's boards. Copied from `PDBoard`.
    public struct Board {
        /// Passed as `boardID` to the other calls.
        public let boardID: String
        /// Display name.
        public let name: String

        init(_ board: PDBoard) {
            boardID = String(playdateCString: board.boardID) ?? ""
            name = String(playdateCString: board.name) ?? ""
        }
    }
}
