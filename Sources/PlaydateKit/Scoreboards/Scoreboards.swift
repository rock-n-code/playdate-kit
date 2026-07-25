internal import CPlaydate

/// The cached `playdate->scoreboards` C API table.
var scoreboardsAPI: UnsafePointer<playdate_scoreboards> { Playdate.scoreboardsAPI.unsafelyUnwrapped }

/// The scoreboards API for games with online leaderboards.
///
/// The C callbacks carry no userdata, so one completion per operation kind
/// is tracked at a time; starting a second request of the same kind before
/// the first completes replaces the stored completion.
public enum Scoreboards {}

extension Scoreboards {
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
            scoreboardsAPI.pointee.addScore.unsafelyUnwrapped(cBoardID, value, { score, errorMessage in
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
            scoreboardsAPI.pointee.getPersonalBest.unsafelyUnwrapped(cBoardID, { score, errorMessage in
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
        return scoreboardsAPI.pointee.getScoreboards.unsafelyUnwrapped({ boards, errorMessage in
            let completion = Scoreboards.boardsCompletion
            Scoreboards.boardsCompletion = nil
            guard let boards else {
                completion?(.failure(PlaydateError(cString: errorMessage)))
                return
            }
            let list = BoardsList(boards.pointee)
            scoreboardsAPI.pointee.freeBoardsList.unsafelyUnwrapped(boards)
            completion?(.success(list))
        }) != 0
    }

    /// Fetches the scores on the board.
    @discardableResult
    public static func getScores(boardID: String,
                                 completion: @escaping (Result<ScoresList, PlaydateError>) -> Void) -> Bool {
        scoresCompletion = completion
        return boardID.withPlaydateCString { cBoardID in
            scoreboardsAPI.pointee.getScores.unsafelyUnwrapped(cBoardID, { scores, errorMessage in
                let completion = Scoreboards.scoresCompletion
                Scoreboards.scoresCompletion = nil
                guard let scores else {
                    completion?(.failure(PlaydateError(cString: errorMessage)))
                    return
                }
                let list = ScoresList(scores.pointee)
                scoreboardsAPI.pointee.freeScoresList.unsafelyUnwrapped(scores)
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
        scoreboardsAPI.pointee.freeScore.unsafelyUnwrapped(score)
        return .success(value)
    }
}
