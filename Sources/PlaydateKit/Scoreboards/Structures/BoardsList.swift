internal import CPlaydate

extension Scoreboards {
    /// The game's boards.
    public struct BoardsList {
        public let lastUpdated: UInt32
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
