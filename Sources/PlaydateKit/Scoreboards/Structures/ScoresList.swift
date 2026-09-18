internal import CPlaydate

extension Scoreboards {
    /// The scores on a board. Copied from `PDScoresList`.
    public struct ScoresList {
        public let boardID: String
        /// Last update, in seconds since the epoch.
        public let lastUpdated: UInt32
        /// Whether the current player's score is in the list.
        public let playerIncluded: Bool
        /// Maximum number of scores the list can hold.
        public let limit: UInt32
        /// Ordered by rank.
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
