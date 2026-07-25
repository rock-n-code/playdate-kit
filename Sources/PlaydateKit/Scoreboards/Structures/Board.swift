internal import CPlaydate

extension Scoreboards {
    /// A board belonging to the game.
    public struct Board {
        public let boardID: String
        public let name: String

        init(_ board: PDBoard) {
            boardID = String(playdateCString: board.boardID) ?? ""
            name = String(playdateCString: board.name) ?? ""
        }
    }
}
