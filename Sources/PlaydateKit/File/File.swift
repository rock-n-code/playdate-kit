internal import CPlaydate

var fileAPI: UnsafePointer<playdate_file> { Playdate.fileAPI.unsafelyUnwrapped }

/// The most recent file system error as a thrown error.
func lastFileError() -> PlaydateError {
    PlaydateError(cString: fileAPI.pointee.geterr.unsafelyUnwrapped())
}

/// The file API: access to the game's Data directory and pdx contents.
public enum File {}

extension File {
    // MARK: - Directory operations

    /// Calls `each` with the name of every file in `path`. Subdirectory names
    /// end in a slash. Throws if the directory does not exist.
    public static func listFiles(at path: String, showHidden: Bool = false,
                                 _ each: (String) -> Void) throws(PlaydateError) {
        let result = withoutActuallyEscaping(each) { each in
            var callback = each
            return path.withPlaydateCString { cPath in
                withUnsafeMutablePointer(to: &callback) { callbackPointer in
                    fileAPI.pointee.listfiles.unsafelyUnwrapped(cPath, { cName, userdata in
                        guard let cName, let userdata else { return }
                        let each = userdata.assumingMemoryBound(to: ((String) -> Void).self).pointee
                        each(String(playdateCString: cName))
                    }, callbackPointer, showHidden ? 1 : 0)
                }
            }
        }
        if result != 0 { throw lastFileError() }
    }

    /// Information about the file or directory at `path`.
    public static func stat(_ path: String) throws(PlaydateError) -> Stat {
        var stat = FileStat()
        let result = path.withPlaydateCString { fileAPI.pointee.stat.unsafelyUnwrapped($0, &stat) }
        if result != 0 { throw lastFileError() }
        return Stat(
            isDirectory: stat.isdir != 0,
            size: stat.size,
            modified: System.DateTime(
                year: UInt16(stat.m_year), month: UInt8(stat.m_month), day: UInt8(stat.m_day),
                hour: UInt8(stat.m_hour), minute: UInt8(stat.m_minute), second: UInt8(stat.m_second)))
    }

    /// Creates a directory (and intermediate directories) in the Data directory.
    public static func mkdir(_ path: String) throws(PlaydateError) {
        let result = path.withPlaydateCString { fileAPI.pointee.mkdir.unsafelyUnwrapped($0) }
        if result != 0 { throw lastFileError() }
    }

    /// Deletes the file or directory at `path`. Directories require
    /// `recursive` to be deleted with their contents.
    public static func unlink(_ path: String, recursive: Bool = false) throws(PlaydateError) {
        let result = path.withPlaydateCString {
            fileAPI.pointee.unlink.unsafelyUnwrapped($0, recursive ? 1 : 0)
        }
        if result != 0 { throw lastFileError() }
    }

    /// Renames (moves) a file in the Data directory, overwriting any existing
    /// file at the destination.
    public static func rename(from: String, to: String) throws(PlaydateError) {
        let result = from.withPlaydateCString { cFrom in
            to.withPlaydateCString { cTo in
                fileAPI.pointee.rename.unsafelyUnwrapped(cFrom, cTo)
            }
        }
        if result != 0 { throw lastFileError() }
    }
}
