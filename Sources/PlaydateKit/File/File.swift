internal import CPlaydate

/// Cached `playdate->file` table.
var fileAPI: UnsafePointer<playdate_file> { Playdate.fileAPI.unsafelyUnwrapped }

/// The most recent file error, with the OS's description.
func lastFileError() -> PlaydateError {
    PlaydateError(cString: fileAPI.pointee.geterr.unsafelyUnwrapped())
}

/// The file API. Paths are relative to the Data directory (writable) or the pdx (read-only).
/// Every throwing API throws `PlaydateError` with the OS's description on failure.
public enum File {}

extension File {
    // MARK: - Directory operations

    /// Calls `each` with each entry name in `path`, non-recursively; directories end in `/`.
    /// Skips `.`-prefixed names unless `showHidden`. Throws if `path` can't be opened.
    public static func listFiles(at path: String, showHidden: Bool = false,
                                 _ each: (String) -> Void) throws(PlaydateError) {
        let result = withoutActuallyEscaping(each) { each in
            var callback = each
            return path.withCString { cPath in
                withUnsafeMutablePointer(to: &callback) { callbackPointer in
                    fileAPI.pointee.listfiles.unsafelyUnwrapped(cPath, { cName, userdata in
                        guard let cName, let userdata else { return }
                        let each = userdata.assumingMemoryBound(to: ((String) -> Void).self).pointee
                        each(String(cString: cName))
                    }, callbackPointer, showHidden ? 1 : 0)
                }
            }
        }
        if result != 0 { throw lastFileError() }
    }

    /// Information about the file or directory at `path`; throws if it is missing.
    public static func stat(_ path: String) throws(PlaydateError) -> Stat {
        var stat = FileStat()
        let result = path.withCString { fileAPI.pointee.stat.unsafelyUnwrapped($0, &stat) }
        if result != 0 { throw lastFileError() }
        return Stat(
            isDirectory: stat.isdir != 0,
            size: stat.size,
            modified: System.DateTime(
                year: UInt16(stat.m_year), month: UInt8(stat.m_month), day: UInt8(stat.m_day),
                hour: UInt8(stat.m_hour), minute: UInt8(stat.m_minute), second: UInt8(stat.m_second)))
    }

    /// Creates directory `path` in the Data directory; does not create intermediate ones.
    public static func mkdir(_ path: String) throws(PlaydateError) {
        let result = path.withCString { fileAPI.pointee.mkdir.unsafelyUnwrapped($0) }
        if result != 0 { throw lastFileError() }
    }

    /// Deletes the file at `path`; with `recursive`, a directory and its contents.
    public static func unlink(_ path: String, recursive: Bool = false) throws(PlaydateError) {
        let result = path.withCString {
            fileAPI.pointee.unlink.unsafelyUnwrapped($0, recursive ? 1 : 0)
        }
        if result != 0 { throw lastFileError() }
    }

    /// Moves `from` to `to` in the Data directory, overwriting `to`; does not create
    /// intermediate directories.
    public static func rename(from: String, to: String) throws(PlaydateError) {
        let result = from.withCString { cFrom in
            to.withCString { cTo in
                fileAPI.pointee.rename.unsafelyUnwrapped(cFrom, cTo)
            }
        }
        if result != 0 { throw lastFileError() }
    }
}
