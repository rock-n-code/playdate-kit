//
//  JSON.swift
//  Wraps `playdate->json` (pd_api_json.h).
//
//  The C decoder is callback-based; this wrapper drives it to build a
//  complete `Value` tree. The encoder is exposed both as a streaming
//  `Encoder` and as a one-shot `encode(_:)` of a `Value`.
//

internal import CPlaydate

private var jsonAPI: playdate_json { Playdate.api.json.pointee }

/// The JSON API: decoding to and encoding from a `Value` tree.
public enum JSON {}

extension JSON {
    /// A decoded JSON value.
    public indirect enum Value {
        case null
        case bool(Bool)
        case int(Int)
        case float(Float)
        case string(String)
        case array([Value])
        case table([String: Value])
    }

    // MARK: - Decoding

    private final class ValueBox {
        var value: Value
        init(_ value: Value) { self.value = value }
    }

    private final class DecodeContext {
        /// Containers under construction, innermost last.
        var stack: [Value] = []
        var errorMessage: String?
        var errorLine: Int32 = 0

        func append(_ value: Value, key: String?) {
            guard !stack.isEmpty else { return }
            switch stack[stack.count - 1] {
            case .array(var items):
                items.append(value)
                stack[stack.count - 1] = .array(items)
            case .table(var entries):
                if let key { entries[key] = value }
                stack[stack.count - 1] = .table(entries)
            default:
                break
            }
        }
    }

    /// Converts a C `json_value`, consuming any container box it references.
    private static func convert(_ value: json_value) -> Value {
        switch UInt32(bitPattern: Int32(value.type)) {
        case kJSONTrue.rawValue: return .bool(true)
        case kJSONFalse.rawValue: return .bool(false)
        case kJSONInteger.rawValue: return .int(Int(value.data.intval))
        case kJSONFloat.rawValue: return .float(value.data.floatval)
        case kJSONString.rawValue: return .string(String(playdateCString: value.data.stringval) ?? "")
        case kJSONArray.rawValue, kJSONTable.rawValue:
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
            context.stack.append(type == kJSONArray ? .array([]) : .table([:]))
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
            return Unmanaged.passRetained(ValueBox(finished)).toOpaque()
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
                jsonAPI.decodeString.unsafelyUnwrapped(&decoder, cString, &outval) != 0
            }
        }
        guard ok else {
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
                jsonAPI.decode.unsafelyUnwrapped(&decoder, reader, &outval) != 0
            }
        }
        guard ok else {
            throw decodeError(context)
        }
        return convert(outval)
    }

    /// Opens and decodes the JSON file at `path`.
    public static func decodeFile(at path: String) throws(PlaydateError) -> Value {
        let file = try File.Handle(path: path, mode: [.read, .readData])
        return try decode(file: file)
    }

    private static func decodeError(_ context: DecodeContext) -> PlaydateError {
        PlaydateError(message: "\(context.errorMessage ?? "JSON decode failed") (line \(context.errorLine))")
    }

    // MARK: - Encoding

    /// A streaming JSON encoder writing into a string. Wraps `json_encoder`.
    public final class Encoder {
        private final class Output {
            var text = ""
        }

        private var encoder = json_encoder()
        private let output = Output()

        public init(pretty: Bool = false) {
            jsonAPI.initEncoder.unsafelyUnwrapped(&encoder, { userdata, string, length in
                guard let userdata, let string else { return }
                let output = Unmanaged<Output>.fromOpaque(userdata).takeUnretainedValue()
                let bytes = UnsafeRawBufferPointer(start: string, count: Int(length))
                output.text += String(decoding: bytes, as: UTF8.self)
            }, Unmanaged.passUnretained(output).toOpaque(), pretty ? 1 : 0)
        }

        /// The JSON produced so far.
        public var json: String { output.text }

        public func startArray() {
            withUnsafeMutablePointer(to: &encoder) { $0.pointee.startArray.unsafelyUnwrapped($0) }
        }

        /// Call before writing each array element.
        public func addArrayMember() {
            withUnsafeMutablePointer(to: &encoder) { $0.pointee.addArrayMember.unsafelyUnwrapped($0) }
        }

        public func endArray() {
            withUnsafeMutablePointer(to: &encoder) { $0.pointee.endArray.unsafelyUnwrapped($0) }
        }

        public func startTable() {
            withUnsafeMutablePointer(to: &encoder) { $0.pointee.startTable.unsafelyUnwrapped($0) }
        }

        /// Call before writing each table value.
        public func addTableMember(name: String) {
            name.withPlaydateCString { cName in
                withUnsafeMutablePointer(to: &encoder) {
                    $0.pointee.addTableMember.unsafelyUnwrapped($0, cName, Int32(name.utf8.count))
                }
            }
        }

        public func endTable() {
            withUnsafeMutablePointer(to: &encoder) { $0.pointee.endTable.unsafelyUnwrapped($0) }
        }

        public func writeNull() {
            withUnsafeMutablePointer(to: &encoder) { $0.pointee.writeNull.unsafelyUnwrapped($0) }
        }

        public func writeBool(_ value: Bool) {
            withUnsafeMutablePointer(to: &encoder) {
                (value ? $0.pointee.writeTrue : $0.pointee.writeFalse).unsafelyUnwrapped($0)
            }
        }

        public func writeInt(_ value: Int) {
            withUnsafeMutablePointer(to: &encoder) { $0.pointee.writeInt.unsafelyUnwrapped($0, Int32(value)) }
        }

        public func writeDouble(_ value: Double) {
            withUnsafeMutablePointer(to: &encoder) { $0.pointee.writeDouble.unsafelyUnwrapped($0, value) }
        }

        public func writeString(_ value: String) {
            value.withPlaydateCString { cString in
                withUnsafeMutablePointer(to: &encoder) {
                    $0.pointee.writeString.unsafelyUnwrapped($0, cString, Int32(value.utf8.count))
                }
            }
        }

        /// Writes a complete `Value` tree.
        public func write(_ value: Value) {
            switch value {
            case .null:
                writeNull()
            case .bool(let bool):
                writeBool(bool)
            case .int(let int):
                writeInt(int)
            case .float(let float):
                writeDouble(Double(float))
            case .string(let string):
                writeString(string)
            case .array(let items):
                startArray()
                for item in items {
                    addArrayMember()
                    write(item)
                }
                endArray()
            case .table(let entries):
                startTable()
                for (key, entry) in entries {
                    addTableMember(name: key)
                    write(entry)
                }
                endTable()
            }
        }
    }

    /// Encodes a `Value` tree as a JSON string.
    public static func encode(_ value: Value, pretty: Bool = false) -> String {
        let encoder = Encoder(pretty: pretty)
        encoder.write(value)
        return encoder.json
    }
}
