/// リテラル、データモデルバインディング、または関数呼び出し結果のいずれかで表されるブール値。
public enum DynamicBoolean: Sendable, Equatable {
    case literal(Bool)
    case binding(DataBinding)
    case functionCall(FunctionCall)
}

// MARK: - Codable

extension DynamicBoolean: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            self = .literal(bool)
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
                debugDescription: "Cannot decode DynamicBoolean"
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

// MARK: - ExpressibleByBooleanLiteral

extension DynamicBoolean: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .literal(value)
    }
}
