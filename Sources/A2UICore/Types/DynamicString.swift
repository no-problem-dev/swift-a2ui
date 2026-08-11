import StructuredDataCore
/// A string a component displays: written into the message (`literal`), read from the data model
/// (`binding`), or produced by a catalog function (`functionCall`).
///
/// Only `binding` ties the component to later `UpdateDataModel` messages — a `literal` is frozen at
/// the moment the agent wrote it, and an editable input given a literal appears to reject every
/// keystroke because there is no path to write back to. A bound path that matches nothing reads
/// as `""`.
///
/// Conforms to `ExpressibleByStringLiteral`, so `"Submit"` builds `.literal("Submit")`.
public enum DynamicString: Sendable, Equatable {
    case literal(String)
    case binding(DataBinding)
    case functionCall(FunctionCall)
}

// MARK: - Codable

extension DynamicString: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let string = try? container.decode(String.self) {
            self = .literal(string)
            return
        }

        // Try keyed container to distinguish DataBinding ("path") from FunctionCall ("call")
        let keyed = try decoder.container(keyedBy: DiscriminatorKeys.self)
        if keyed.allKeys.contains(.path) {
            self = .binding(try DataBinding(from: decoder))
        } else if keyed.allKeys.contains(.call) {
            self = .functionCall(try FunctionCall(from: decoder))
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode DynamicString"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .literal(let value):
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

// MARK: - ExpressibleByStringLiteral

extension DynamicString: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .literal(value)
    }
}
