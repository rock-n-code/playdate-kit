internal import CPlaydate

extension Scoreboards {
    /// A board belonging to the game.
    public struct Board {
        /// The board's identifier, used in the other scoreboard calls.
        public let boardID: String
        /// The board's display name.
        public let name: String

        init(_ board: PDBoard) {
            boardID = String(playdateCString: board.boardID) ?? ""
            name = String(playdateCString: board.name) ?? ""
        }
    }
}
