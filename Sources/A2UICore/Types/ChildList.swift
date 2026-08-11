/// How a container names its children: a fixed list of component ids, or one template component
/// instantiated once per element of a bound collection.
///
/// The two are told apart by JSON shape, not by a discriminator — `ids` is an array of strings,
/// `template` an object with `componentId` and `path`. Inside a template instance the data scope
/// moves to the element, so bindings there are written relative to it and the built-in `@index`
/// resolves (spec §collection scopes).
public enum ChildList: Sendable, Equatable {
    case ids([String])
    case template(componentId: String, path: String)
}

// MARK: - Codable

extension ChildList: Codable {
    public init(from decoder: Decoder) throws {
        // Array of strings → ids case
        if var unkeyed = try? decoder.unkeyedContainer() {
            var result: [String] = []
            while !unkeyed.isAtEnd {
                result.append(try unkeyed.decode(String.self))
            }
            self = .ids(result)
            return
        }

        // Object with "componentId" and "path" → template case
        let keyed = try decoder.container(keyedBy: CodingKeys.self)
        let componentId = try keyed.decode(String.self, forKey: .componentId)
        let path = try keyed.decode(String.self, forKey: .path)
        self = .template(componentId: componentId, path: path)
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .ids(let value):
            var container = encoder.unkeyedContainer()
            for id in value {
                try container.encode(id)
            }
        case .template(let componentId, let path):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(componentId, forKey: .componentId)
            try container.encode(path, forKey: .path)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case componentId, path
    }
}
