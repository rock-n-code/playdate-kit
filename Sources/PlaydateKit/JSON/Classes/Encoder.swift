internal import CPlaydate

extension JSON {
    /// A streaming JSON encoder writing into a string. Wraps `json_encoder`.
    public final class Encoder {
        private final class Output {
            var bytes: [UInt8] = []
        }

        private var encoder = json_encoder()
        private let output = Output()

        public init(pretty: Bool = false) {
            jsonAPI.pointee.initEncoder.unsafelyUnwrapped(&encoder, { userdata, string, length in
                guard let userdata, let string else { return }
                let output = Unmanaged<Output>.fromOpaque(userdata).takeUnretainedValue()
                output.bytes.append(contentsOf: UnsafeRawBufferPointer(start: string, count: Int(length)))
            }, Unmanaged.passUnretained(output).toOpaque(), pretty ? 1 : 0)
        }

        /// The JSON produced so far.
        public var json: String { String(decoding: output.bytes, as: UTF8.self) }

        /// Starts a JSON array.
        public func startArray() {
            withUnsafeMutablePointer(to: &encoder) { $0.pointee.startArray.unsafelyUnwrapped($0) }
        }

        /// Call before writing each array element.
        public func addArrayMember() {
            withUnsafeMutablePointer(to: &encoder) { $0.pointee.addArrayMember.unsafelyUnwrapped($0) }
        }

        /// Ends the current array.
        public func endArray() {
            withUnsafeMutablePointer(to: &encoder) { $0.pointee.endArray.unsafelyUnwrapped($0) }
        }

        /// Starts a JSON object.
        public func startTable() {
            withUnsafeMutablePointer(to: &encoder) { $0.pointee.startTable.unsafelyUnwrapped($0) }
        }

        /// Call before writing each table value.
        public func addTableMember(name: String) {
            name.withPlaydateUTF8 { bytes, count in
                withUnsafeMutablePointer(to: &encoder) {
                    $0.pointee.addTableMember.unsafelyUnwrapped(
                        $0, bytes.assumingMemoryBound(to: CChar.self), Int32(count))
                }
            }
        }

        /// Ends the current object.
        public func endTable() {
            withUnsafeMutablePointer(to: &encoder) { $0.pointee.endTable.unsafelyUnwrapped($0) }
        }

        /// Writes a `null` value.
        public func writeNull() {
            withUnsafeMutablePointer(to: &encoder) { $0.pointee.writeNull.unsafelyUnwrapped($0) }
        }

        /// Writes a boolean value.
        public func writeBool(_ value: Bool) {
            withUnsafeMutablePointer(to: &encoder) {
                (value ? $0.pointee.writeTrue : $0.pointee.writeFalse).unsafelyUnwrapped($0)
            }
        }

        /// Writes an integer value.
        public func writeInt(_ value: Int) {
            withUnsafeMutablePointer(to: &encoder) { $0.pointee.writeInt.unsafelyUnwrapped($0, Int32(value)) }
        }

        /// Writes a floating-point value.
        public func writeDouble(_ value: Double) {
            withUnsafeMutablePointer(to: &encoder) { $0.pointee.writeDouble.unsafelyUnwrapped($0, value) }
        }

        /// Writes a string value.
        public func writeString(_ value: String) {
            value.withPlaydateUTF8 { bytes, count in
                withUnsafeMutablePointer(to: &encoder) {
                    $0.pointee.writeString.unsafelyUnwrapped(
                        $0, bytes.assumingMemoryBound(to: CChar.self), Int32(count))
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
}
