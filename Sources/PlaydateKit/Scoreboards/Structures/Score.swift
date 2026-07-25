internal import CPlaydate

extension Scoreboards {
    /// A score on a board.
    public struct Score {
        public let rank: UInt32
        public let value: UInt32
        public let player: String
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
