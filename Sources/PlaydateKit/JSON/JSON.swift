internal import CPlaydate

/// Cached `playdate->json` table.
var jsonAPI: UnsafePointer<playdate_json> { Playdate.jsonAPI.unsafelyUnwrapped }

/// The JSON API: decodes to a complete `Value` tree; encodes by streaming (`Encoder`)
/// or in one shot (`encode(_:pretty:)`).
public enum JSON {}

extension JSON {
    // MARK: - Decoding

    /// Boxes a finished container to pass through the C decoder as a `void*`.
    private final class ValueBox {
        var value: Value
        init(_ value: Value) { self.value = value }
    }

    /// A container being built; a class so appends don't copy out of an enum payload.
    private final class Container {
        let isArray: Bool
        var items: [Value] = []
        var entries: [String: Value] = [:]

        init(isArray: Bool) { self.isArray = isArray }

        var value: Value { isArray ? .array(items) : .table(entries) }
    }

    private final class DecodeContext {
        /// Open containers, innermost last.
        var stack: [Container] = []
        var errorMessage: String?
        var errorLine: Int32 = 0

        func append(_ value: Value, key: String?) {
            guard let container = stack.last else { return }
            if container.isArray {
                container.items.append(value)
            } else if let key {
                container.entries[key] = value
            }
        }
    }

    /// Converts a C `json_value`, consuming any container box it references.
    private static func convert(_ value: json_value) -> Value {
        switch UInt32(bitPattern: Int32(value.type)) {
        case UInt32(kJSONTrue.rawValue): return .bool(true)
        case UInt32(kJSONFalse.rawValue): return .bool(false)
        case UInt32(kJSONInteger.rawValue): return .int(Int(value.data.intval))
        case UInt32(kJSONFloat.rawValue): return .float(value.data.floatval)
        case UInt32(kJSONString.rawValue): return .string(String(playdateCString: value.data.stringval) ?? "")
        case UInt32(kJSONArray.rawValue), UInt32(kJSONTable.rawValue):
            guard let pointer = value.data.arrayval else { return .null }
            return Unmanaged<ValueBox>.fromOpaque(pointer).takeRetainedValue().value
        default: return .null
        }
    }

    private static func makeDecoder(context: Unmanaged<DecodeContext>) -> json_decoder {
        var decoder = json_decoder()
        decoder.userdata = context.toOpaque()
        decoder.decodeError = { decoder, error, linenum in
            guard let userdata = decoder?.pointee.userdata else { return }
            let context = Unmanaged<DecodeContext>.fromOpaque(userdata).takeUnretainedValue()
            context.errorMessage = String(playdateCString: error)
            context.errorLine = linenum
        }
        decoder.willDecodeSublist = { decoder, _, type in
            guard let userdata = decoder?.pointee.userdata else { return }
            let context = Unmanaged<DecodeContext>.fromOpaque(userdata).takeUnretainedValue()
            context.stack.append(Container(isArray: type == kJSONArray))
        }
        decoder.didDecodeTableValue = { decoder, key, value in
            guard let userdata = decoder?.pointee.userdata else { return }
            let context = Unmanaged<DecodeContext>.fromOpaque(userdata).takeUnretainedValue()
            context.append(JSON.convert(value), key: String(playdateCString: key))
        }
        decoder.didDecodeArrayValue = { decoder, _, value in
            guard let userdata = decoder?.pointee.userdata else { return }
            let context = Unmanaged<DecodeContext>.fromOpaque(userdata).takeUnretainedValue()
            context.append(JSON.convert(value), key: nil)
        }
        decoder.didDecodeSublist = { decoder, _, _ in
            guard let userdata = decoder?.pointee.userdata else { return nil }
            let context = Unmanaged<DecodeContext>.fromOpaque(userdata).takeUnretainedValue()
            guard let finished = context.stack.popLast() else { return nil }
            // Goes to the parent's callback (or `outval` for the root); `convert` releases it.
            return Unmanaged.passRetained(ValueBox(finished.value)).toOpaque()
        }
        return decoder
    }

    /// Decodes `jsonString`; throws the decoder's error message on failure.
    public static func decode(_ jsonString: String) throws(PlaydateError) -> Value {
        let context = DecodeContext()
        let unmanaged = Unmanaged.passUnretained(context)
        var decoder = makeDecoder(context: unmanaged)
        var outval = json_value()
        let ok = jsonString.withCString { cString in
            withExtendedLifetime(context) {
                jsonAPI.pointee.decodeString.unsafelyUnwrapped(&decoder, cString, &outval) != 0
            }
        }
        guard ok else {
            // Consume any root box already written to outval so it isn't leaked.
            _ = convert(outval)
            throw decodeError(context)
        }
        return convert(outval)
    }

    /// Decodes JSON from `file`'s current offset, leaving it open; throws the decoder's
    /// error message on failure.
    public static func decode(file: borrowing File.Handle) throws(PlaydateError) -> Value {
        let context = DecodeContext()
        var decoder = makeDecoder(context: Unmanaged.passUnretained(context))
        var reader = json_reader()
        // Borrowing keeps the `SDFile` open for the whole decode.
        reader.userdata = file.pointer
        reader.read = { userdata, buffer, size in
            // `file->read` returns 0 at end of data, as the decoder expects.
            guard let userdata, let buffer else { return 0 }
            return fileAPI.pointee.read.unsafelyUnwrapped(userdata, buffer, UInt32(size))
        }
        var outval = json_value()
        let ok = withExtendedLifetime(context) {
            jsonAPI.pointee.decode.unsafelyUnwrapped(&decoder, reader, &outval) != 0
        }
        guard ok else {
            // Consume any root box already written to outval so it isn't leaked.
            _ = convert(outval)
            throw decodeError(context)
        }
        return convert(outval)
    }

    /// Decodes the file at `path` (Data directory first, then pdx), closing it on return.
    public static func decodeFile(path: String) throws(PlaydateError) -> Value {
        let file = try File.Handle(path: path, mode: [.read, .readData])
        return try decode(file: file)
    }

    // Static message: interpolating the line number pulls integer formatting into binaries.
    private static func decodeError(_ context: DecodeContext) -> PlaydateError {
        PlaydateError(message: context.errorMessage ?? "JSON decode failed")
    }

    // MARK: - Encoding

    /// Encodes `value`; `pretty` adds formatting. Table keys follow `Dictionary` order.
    public static func encode(_ value: Value, pretty: Bool = false) -> String {
        let encoder = Encoder(pretty: pretty)
        encoder.write(value)
        return encoder.json
    }
}
