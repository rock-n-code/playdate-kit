internal import CPlaydate

var jsonAPI: UnsafePointer<playdate_json> { Playdate.jsonAPI.unsafelyUnwrapped }

/// The JSON API: decoding to and encoding from a `Value` tree.
public enum JSON {}

extension JSON {
    // MARK: - Decoding

    private final class ValueBox {
        var value: Value
        init(_ value: Value) { self.value = value }
    }

    /// A container under construction. A class, so appends mutate uniquely
    /// referenced storage in place instead of copying the collection out of
    /// and back into an enum payload on every element.
    private final class Container {
        let isArray: Bool
        var items: [Value] = []
        var entries: [String: Value] = [:]

        init(isArray: Bool) { self.isArray = isArray }

        var value: Value { isArray ? .array(items) : .table(entries) }
    }

    private final class DecodeContext {
        /// Containers under construction, innermost last.
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
            // Handed to the parent container (or the decode outval) as the
            // sublist's value; consumed by `convert`.
            return Unmanaged.passRetained(ValueBox(finished.value)).toOpaque()
        }
        return decoder
    }

    /// Decodes a JSON string into a `Value` tree.
    public static func decode(_ jsonString: String) throws(PlaydateError) -> Value {
        let context = DecodeContext()
        let unmanaged = Unmanaged.passUnretained(context)
        var decoder = makeDecoder(context: unmanaged)
        var outval = json_value()
        let ok = jsonString.withPlaydateCString { cString in
            withExtendedLifetime(context) {
                jsonAPI.pointee.decodeString.unsafelyUnwrapped(&decoder, cString, &outval) != 0
            }
        }
        guard ok else {
            // A completed root container may already have been written to
            // outval before the failure; consume it so its box is not leaked.
            _ = convert(outval)
            throw decodeError(context)
        }
        return convert(outval)
    }

    /// Decodes JSON read from an open file into a `Value` tree.
    public static func decode(file: File.Handle) throws(PlaydateError) -> Value {
        let context = DecodeContext()
        var decoder = makeDecoder(context: Unmanaged.passUnretained(context))
        var reader = json_reader()
        reader.userdata = Unmanaged.passUnretained(file).toOpaque()
        reader.read = { userdata, buffer, size in
            guard let userdata, let buffer else { return -1 }
            let file = Unmanaged<File.Handle>.fromOpaque(userdata).takeUnretainedValue()
            let destination = UnsafeMutableRawBufferPointer(start: buffer, count: Int(size))
            do {
                let count = try file.read(into: destination)
                return count > 0 ? Int32(count) : -1
            } catch {
                return -1
            }
        }
        var outval = json_value()
        let ok = withExtendedLifetime(context) {
            withExtendedLifetime(file) {
                jsonAPI.pointee.decode.unsafelyUnwrapped(&decoder, reader, &outval) != 0
            }
        }
        guard ok else {
            // A completed root container may already have been written to
            // outval before the failure; consume it so its box is not leaked.
            _ = convert(outval)
            throw decodeError(context)
        }
        return convert(outval)
    }

    /// Opens and decodes the JSON file at `path`.
    public static func decodeFile(at path: String) throws(PlaydateError) -> Value {
        let file = try File.Handle(path: path, mode: [.read, .readData])
        return try decode(file: file)
    }

    // Static message: interpolating the line number would pull integer
    // formatting machinery into every device binary that decodes JSON.
    private static func decodeError(_ context: DecodeContext) -> PlaydateError {
        PlaydateError(message: context.errorMessage ?? "JSON decode failed")
    }

    // MARK: - Encoding

    /// Encodes a `Value` tree as a JSON string.
    public static func encode(_ value: Value, pretty: Bool = false) -> String {
        let encoder = Encoder(pretty: pretty)
        encoder.write(value)
        return encoder.json
    }
}
