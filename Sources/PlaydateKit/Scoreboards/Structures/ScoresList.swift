internal import CPlaydate

extension Scoreboards {
    /// The scores on a board.
    public struct ScoresList {
        /// The board the scores belong to.
        public let boardID: String
        /// When the list was last updated, in seconds since the epoch.
        public let lastUpdated: UInt32
        /// Whether the current player's score is included in the list.
        public let playerIncluded: Bool
        /// The maximum number of scores the list can hold.
        public let limit: UInt32
        /// The scores, ordered by rank.
        public let scores: [Score]

        init(_ list: PDScoresList) {
            boardID = String(playdateCString: list.boardID) ?? ""
            lastUpdated = list.lastUpdated
            playerIncluded = list.playerIncluded != 0
            limit = list.limit
            var scores = [Score]()
            if let entries = list.scores {
                scores.reserveCapacity(Int(list.count))
                for index in 0..<Int(list.count) {
                    scores.append(Score(entries[index], boardID: boardID))
                }
            }
            self.scores = scores
        }
    }
}
