internal import CPlaydate

extension Scoreboards {
    /// A score on a board.
    public struct Score {
        /// The score's position on the board, starting at 1.
        public let rank: UInt32
        /// The score's value.
        public let value: UInt32
        /// The name of the player who posted the score.
        public let player: String
        /// The board the score belongs to, when known.
        public let boardID: String?

        init(_ score: PDScore) {
            rank = score.rank
            value = score.value
            player = String(playdateCString: score.player) ?? ""
            boardID = String(playdateCString: score.boardID)
        }

        init(_ score: PDListScore, boardID: String?) {
            rank = score.rank
            value = score.value
            player = String(playdateCString: score.player) ?? ""
            self.boardID = boardID
        }
    }
}
