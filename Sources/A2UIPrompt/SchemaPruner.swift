import A2UICore
import Foundation

/// LLM プロンプト用に JSON Schema をプルーニングする純関数群。
///
/// Python 公式 SDK (`agent_sdks/python/src/a2ui/schema/catalog.py`) の
/// `_collect_refs` / `_prune_defs_by_reachability` / `_with_pruned_common_types` /
/// `_with_pruned_messages` 相当の Swift 移植。
///
/// 使い方の組み合わせ:
/// 1. `pruneMessages(serverToClient:allowedMessages:)`: server_to_client の oneOf と $defs を絞る
/// 2. `pruneCommonTypes(commonTypes:reachableFrom:)`: catalog と s2c で参照されない common_types を削る
///
/// LLM が直接 schema 内の URL を辿るわけではないが、未使用の型定義はノイズなので削るとプロンプトが軽くなる。
public enum SchemaPruner {

    // MARK: - Public API

    /// `server_to_client` の `oneOf` と `$defs` を allowed messages で絞り込む。
    ///
    /// - Parameters:
    ///   - serverToClient: 元の server_to_client schema（パース済み）
    ///   - allowedMessages: 残すメッセージ型名（例: `["CreateSurfaceMessage", "UpdateComponentsMessage"]`）
    /// - Returns: oneOf が絞られ、到達不能な `$defs` が除去された schema
    public static func pruneMessages(
        serverToClient: AnyCodable,
        allowedMessages: Set<String>
    ) -> AnyCodable {
        guard case .object(var root) = serverToClient else { return serverToClient }

        // 1. oneOf を allowed の "#/$defs/X" にマッチするもののみ残す
        if case .array(let oneOf)? = root["oneOf"] {
            let filtered = oneOf.filter { item in
                guard case .object(let dict) = item,
                      case .string(let ref)? = dict["$ref"],
                      let name = lastSegment(ofInternalRef: ref) else {
                    return true  // 形式不明のものは保守的に残す
                }
                return allowedMessages.contains(name)
            }
            root["oneOf"] = .array(filtered)
        }

        // 2. $defs を allowed_messages から到達可能性 BFS で絞る
        if case .object(let defs)? = root["$defs"] {
            let pruned = pruneByReachability(
                defs: defs,
                roots: allowedMessages,
                internalRefPrefix: "#/$defs/"
            )
            root["$defs"] = .object(pruned)
        }

        return .object(root)
    }

    /// `common_types` の `$defs` を、`reachableFrom` の各 schema から参照されているものに絞る。
    ///
    /// `$defs` 内部からの相互参照（`#/$defs/X` または `<URL>/common_types.json#/$defs/X`）も
    /// 推移閉包で辿る。
    ///
    /// - Parameters:
    ///   - commonTypes: 元の common_types schema（パース済み）
    ///   - reachableFrom: 参照元になる schema 配列（catalog と server_to_client を渡すのが典型）
    /// - Returns: 到達可能な `$defs` だけが残った schema
    public static func pruneCommonTypes(
        commonTypes: AnyCodable,
        reachableFrom externalSchemas: [AnyCodable]
    ) -> AnyCodable {
        guard case .object(var root) = commonTypes,
              case .object(let defs)? = root["$defs"] else {
            return commonTypes
        }

        // 1. 外部 schema 群から "common_types.json#/$defs/X" 形式の $ref を全て収集
        var rootNames: Set<String> = []
        for schema in externalSchemas {
            for ref in collectRefs(in: schema) {
                if let name = name(ofCommonTypesRef: ref) {
                    rootNames.insert(name)
                }
            }
        }

        // 2. $defs 内部の相互参照を BFS で推移閉包。`#/$defs/X` と URL 形式の両方を受け付ける
        var visited: Set<String> = []
        var queue: [String] = Array(rootNames)
        while !queue.isEmpty {
            let name = queue.removeFirst()
            guard defs[name] != nil, !visited.contains(name) else { continue }
            visited.insert(name)
            for ref in collectRefs(in: defs[name]!) {
                if let inner = lastSegment(ofInternalRef: ref) ?? self.name(ofCommonTypesRef: ref) {
                    queue.append(inner)
                }
            }
        }
        root["$defs"] = .object(defs.filter { visited.contains($0.key) })
        return .object(root)
    }

    /// JSON 構造の中から全ての `$ref` 値を再帰的に集める。
    public static func collectRefs(in value: AnyCodable) -> Set<String> {
        var refs: Set<String> = []
        collectRefsInternal(value, into: &refs)
        return refs
    }

    // MARK: - Internal

    /// 与えられた `$defs` を、`roots` から `internalRefPrefix` 経由で到達可能なエントリのみに絞る。
    static func pruneByReachability(
        defs: [String: AnyCodable],
        roots: Set<String>,
        internalRefPrefix: String
    ) -> [String: AnyCodable] {
        var visited: Set<String> = []
        var queue: [String] = Array(roots)

        while let name = queue.popFirst() {
            guard defs[name] != nil, !visited.contains(name) else { continue }
            visited.insert(name)
            for ref in collectRefs(in: defs[name]!) {
                if ref.hasPrefix(internalRefPrefix) {
                    let key = String(ref.dropFirst(internalRefPrefix.count))
                    queue.append(key)
                }
            }
        }

        return defs.filter { visited.contains($0.key) }
    }

    private static func collectRefsInternal(_ value: AnyCodable, into refs: inout Set<String>) {
        switch value {
        case .object(let dict):
            for (key, child) in dict {
                if key == "$ref", case .string(let s) = child {
                    refs.insert(s)
                } else {
                    collectRefsInternal(child, into: &refs)
                }
            }
        case .array(let arr):
            for item in arr {
                collectRefsInternal(item, into: &refs)
            }
        default:
            break
        }
    }

    /// `"https://.../common_types.json#/$defs/DynamicString"` -> `"DynamicString"`
    private static func name(ofCommonTypesRef ref: String) -> String? {
        let marker = "common_types.json#/$defs/"
        guard let range = ref.range(of: marker) else { return nil }
        return String(ref[range.upperBound...])
    }

    /// `"#/$defs/CreateSurfaceMessage"` -> `"CreateSurfaceMessage"`
    private static func lastSegment(ofInternalRef ref: String) -> String? {
        let prefix = "#/$defs/"
        guard ref.hasPrefix(prefix) else { return nil }
        return String(ref.dropFirst(prefix.count))
    }
}

// MARK: - Array popFirst helper

private extension Array {
    mutating func popFirst() -> Element? {
        guard !isEmpty else { return nil }
        return removeFirst()
    }
}
