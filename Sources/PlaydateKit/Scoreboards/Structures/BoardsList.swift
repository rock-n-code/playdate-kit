internal import CPlaydate

extension Scoreboards {
    /// The game's boards.
    public struct BoardsList {
        /// When the list was last updated, in seconds since the epoch.
        public let lastUpdated: UInt32
        /// The game's boards.
        public let boards: [Board]

        init(_ list: PDBoardsList) {
            lastUpdated = list.lastUpdated
            var boards = [Board]()
            if let entries = list.boards {
                boards.reserveCapacity(Int(list.count))
                for index in 0..<Int(list.count) {
                    boards.append(Board(entries[index]))
                }
            }
            self.boards = boards
        }
    }
}
