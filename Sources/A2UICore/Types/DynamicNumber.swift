import StructuredDataCore
/// A numeric property — a slider value, a step, a count — always carried as a `Double`, whatever
/// the JSON looked like.
///
/// `literal` is fixed in the message, `binding` is re-read from the data model, `functionCall` is
/// computed by the catalog. A bound path that matches nothing coerces to `0`, which most layouts
/// treat as a deliberate value, so an unpopulated model is indistinguishable from a real zero.
///
/// Conforms to `ExpressibleByIntegerLiteral` as well as `ExpressibleByFloatLiteral`: `4` and `4.0`
/// both build `.literal(4.0)`.
public enum DynamicNumber: Sendable, Equatable {
    case literal(Double)
    case binding(DataBinding)
    case functionCall(FunctionCall)
}

// MARK: - Codable

extension DynamicNumber: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let number = try? container.decode(Double.self) {
            self = .literal(number)
            return
        }

        let keyed = try decoder.container(keyedBy: DiscriminatorKeys.self)
        if keyed.allKeys.contains(.path) {
            self = .binding(try DataBinding(from: decoder))
        } else if keyed.allKeys.contains(.call) {
            self = .functionCall(try FunctionCall(from: decoder))
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode DynamicNumber"
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

// MARK: - ExpressibleBy Literals

extension DynamicNumber: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .literal(value)
    }
}

extension DynamicNumber: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .literal(Double(value))
    }
}
