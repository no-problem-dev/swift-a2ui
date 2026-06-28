/// リテラル、データモデルバインディング、または関数呼び出し結果のいずれかで表される文字列配列。
public enum DynamicStringList: Sendable, Equatable {
    case literal([String])
    case binding(DataBinding)
    case functionCall(FunctionCall)
}

// MARK: - Codable

extension DynamicStringList: Codable {
    public init(from decoder: Decoder) throws {
        // Try array first via unkeyed container
        if let strings = try? decoder.singleValueContainer().decode([String].self) {
            self = .literal(strings)
            return
        }

        let keyed = try decoder.container(keyedBy: DiscriminatorKeys.self)
        if keyed.allKeys.contains(.path) {
            self = .binding(try DataBinding(from: decoder))
        } else if keyed.allKeys.contains(.call) {
            self = .functionCall(try FunctionCall(from: decoder))
        } else {
            let container = try decoder.singleValueContainer()
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode DynamicStringList"
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
