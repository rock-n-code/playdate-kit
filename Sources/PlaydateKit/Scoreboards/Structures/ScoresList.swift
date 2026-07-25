internal import CPlaydate

extension Scoreboards {
    /// The scores on a board.
    public struct ScoresList {
        public let boardID: String
        public let lastUpdated: UInt32
        public let playerIncluded: Bool
        public let limit: UInt32
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
