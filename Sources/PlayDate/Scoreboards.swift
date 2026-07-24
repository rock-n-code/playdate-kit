//
//  Scoreboards.swift
//  Wraps `playdate->scoreboards` (pd_api_scoreboards.h).
//
//  The C callbacks carry no userdata, so one completion per operation kind
//  is tracked at a time; starting a second request of the same kind before
//  the first completes replaces the stored completion.
//

internal import CPlaydate

private var scoreboardsAPI: playdate_scoreboards { Playdate.api.scoreboards.pointee }

/// The scoreboards API for games with online leaderboards.
public enum Scoreboards {}

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

    /// A board belonging to the game.
    public struct Board {
        public let boardID: String
        public let name: String

        init(_ board: PDBoard) {
            boardID = String(playdateCString: board.boardID) ?? ""
            name = String(playdateCString: board.name) ?? ""
        }
    }

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

    nonisolated(unsafe) private static var addScoreCompletion: ((Result<Score, PlaydateError>) -> Void)?
    nonisolated(unsafe) private static var personalBestCompletion: ((Result<Score, PlaydateError>) -> Void)?
    nonisolated(unsafe) private static var boardsCompletion: ((Result<BoardsList, PlaydateError>) -> Void)?
    nonisolated(unsafe) private static var scoresCompletion: ((Result<ScoresList, PlaydateError>) -> Void)?

    /// Submits a score to the board. Returns `false` if the request could
    /// not be started.
    @discardableResult
    public static func addScore(boardID: String, value: UInt32,
                                completion: @escaping (Result<Score, PlaydateError>) -> Void) -> Bool {
        addScoreCompletion = completion
        return boardID.withPlaydateCString { cBoardID in
            scoreboardsAPI.addScore.unsafelyUnwrapped(cBoardID, value, { score, errorMessage in
                let completion = Scoreboards.addScoreCompletion
                Scoreboards.addScoreCompletion = nil
                completion?(Scoreboards.result(score, errorMessage))
            }) != 0
        }
    }

    /// Fetches the current player's best score on the board.
    @discardableResult
    public static func getPersonalBest(boardID: String,
                                       completion: @escaping (Result<Score, PlaydateError>) -> Void) -> Bool {
        personalBestCompletion = completion
        return boardID.withPlaydateCString { cBoardID in
            scoreboardsAPI.getPersonalBest.unsafelyUnwrapped(cBoardID, { score, errorMessage in
                let completion = Scoreboards.personalBestCompletion
                Scoreboards.personalBestCompletion = nil
                completion?(Scoreboards.result(score, errorMessage))
            }) != 0
        }
    }

    /// Fetches the list of the game's boards.
    @discardableResult
    public static func getScoreboards(completion: @escaping (Result<BoardsList, PlaydateError>) -> Void) -> Bool {
        boardsCompletion = completion
        return scoreboardsAPI.getScoreboards.unsafelyUnwrapped({ boards, errorMessage in
            let completion = Scoreboards.boardsCompletion
            Scoreboards.boardsCompletion = nil
            guard let boards else {
                completion?(.failure(PlaydateError(cString: errorMessage)))
                return
            }
            let list = BoardsList(boards.pointee)
            scoreboardsAPI.freeBoardsList.unsafelyUnwrapped(boards)
            completion?(.success(list))
        }) != 0
    }

    /// Fetches the scores on the board.
    @discardableResult
    public static func getScores(boardID: String,
                                 completion: @escaping (Result<ScoresList, PlaydateError>) -> Void) -> Bool {
        scoresCompletion = completion
        return boardID.withPlaydateCString { cBoardID in
            scoreboardsAPI.getScores.unsafelyUnwrapped(cBoardID, { scores, errorMessage in
                let completion = Scoreboards.scoresCompletion
                Scoreboards.scoresCompletion = nil
                guard let scores else {
                    completion?(.failure(PlaydateError(cString: errorMessage)))
                    return
                }
                let list = ScoresList(scores.pointee)
                scoreboardsAPI.freeScoresList.unsafelyUnwrapped(scores)
                completion?(.success(list))
            }) != 0
        }
    }

    private static func result(_ score: UnsafeMutablePointer<PDScore>?,
                               _ errorMessage: UnsafePointer<CChar>?) -> Result<Score, PlaydateError> {
        guard let score else {
            return .failure(PlaydateError(cString: errorMessage))
        }
        let value = Score(score.pointee)
        scoreboardsAPI.freeScore.unsafelyUnwrapped(score)
        return .success(value)
    }
}
