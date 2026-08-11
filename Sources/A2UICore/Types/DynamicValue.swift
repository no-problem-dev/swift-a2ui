import StructuredDataCore
/// The untyped member of the dynamic family: any scalar or array, for places a catalog does not
/// constrain the type — the entries of `EventAction.context`, for instance.
///
/// There is no object case. An object on the wire is read only as a `binding` (it has `path`) or a
/// `functionCall` (it has `call`); any other object fails to decode, so a nested literal must be
/// wrapped in `array` or put in the data model and bound. Booleans are tested before numbers, so
/// `true` never arrives as `1`.
public enum DynamicValue: Sendable, Equatable {
    case string(String)
    case number(Double)
    case boolean(Bool)
    case array([StructuredValue])
    case binding(DataBinding)
    case functionCall(FunctionCall)
}

// MARK: - Codable

extension DynamicValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        // Bool must be tried before number — in JSON, booleans decode as Int on some decoders
        if let bool = try? container.decode(Bool.self) {
            self = .boolean(bool)
            return
        }

        if let string = try? container.decode(String.self) {
            self = .string(string)
            return
        }

        if let number = try? container.decode(Double.self) {
            self = .number(number)
            return
        }

        if let array = try? container.decode([StructuredValue].self) {
            self = .array(array)
            return
        }

        // Keyed container: discriminate between DataBinding ("path") and FunctionCall ("call")
        let keyed = try decoder.container(keyedBy: DiscriminatorKeys.self)
        if keyed.allKeys.contains(.path) {
            self = .binding(try DataBinding(from: decoder))
        } else if keyed.allKeys.contains(.call) {
            self = .functionCall(try FunctionCall(from: decoder))
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode DynamicValue"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .string(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .number(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .boolean(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .array(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .binding(let value):
            try value.encode(to: encoder)
        case .functionCall(let value):
            try value.encode(to: encoder)
        }
    }

    private enum DiscriminatorKeys: String, CodingKey {
        case path, call
    }
}
