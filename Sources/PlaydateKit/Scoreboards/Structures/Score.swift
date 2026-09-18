internal import CPlaydate

extension Scoreboards {
    /// A score on a board. Copied from `PDScore` or `PDListScore`.
    public struct Score {
        /// Position on the board, from 1.
        public let rank: UInt32
        public let value: UInt32
        /// Name of the player who posted it.
        public let player: String
        /// `nil` if the C API gave none.
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
