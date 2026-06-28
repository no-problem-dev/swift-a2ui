/// リテラル、データモデルバインディング、または関数呼び出し結果のいずれかで表される数値。
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
