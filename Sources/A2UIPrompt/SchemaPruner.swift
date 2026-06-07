import A2UICore
import Foundation

/// LLM プロンプト用に JSON Schema をプルーニングする純関数群。
///
/// Python 公式 SDK (`agent_sdks/python/src/a2ui/schema/catalog.py`) の
/// `with_pruning` / `_with_pruned_components` / `_with_pruned_messages` /
/// `_with_pruned_common_types` / `_collect_refs` / `_prune_defs_by_reachability` の
/// 逐語移植。挙動は公式 conformance スイート（`agent_sdks/conformance/suites/catalog.yaml`）の
/// 全 prune ケースをテストで固定している。
///
/// LLM が直接 schema 内の URL を辿るわけではないが、未使用の型定義はノイズなので削るとプロンプトが軽くなる。
public enum SchemaPruner {

    // MARK: - Public API

    /// 公式 `A2uiCatalog.with_pruning` 相当: カタログ三点セットへ 3 段の pruning を適用する。
    ///
    /// 1. `allowedComponents` 指定時: catalog の `components` と `$defs.anyComponent.oneOf` を絞る
    /// 2. `allowedMessages` 指定時: server_to_client の oneOf / properties と `$defs` を絞る
    /// 3. **常時**: pruning 後の catalog + s2c から到達可能な common_types の `$defs` のみ残す
    ///
    /// 順序が規範: common_types の到達可能性は **絞った後の** catalog / s2c から計算される。
    public static func withPruning(
        catalog: StructuredValue,
        serverToClient: StructuredValue,
        commonTypes: StructuredValue,
        allowedComponents: Set<String>? = nil,
        allowedMessages: Set<String>? = nil
    ) -> (catalog: StructuredValue, serverToClient: StructuredValue, commonTypes: StructuredValue) {
        var catalog = catalog
        var s2c = serverToClient
        if let allowedComponents {
            catalog = pruneComponents(catalog: catalog, allowedComponents: allowedComponents)
        }
        if let allowedMessages {
            s2c = pruneMessages(serverToClient: s2c, allowedMessages: allowedMessages)
        }
        let common = pruneCommonTypes(commonTypes: commonTypes, reachableFrom: [catalog, s2c])
        return (catalog, s2c, common)
    }

    /// 公式 `_with_pruned_components` 相当: catalog の `components` を allowed で絞り、
    /// `$defs.anyComponent.oneOf` から不許可コンポーネントへの `$ref` を除去する。
    ///
    /// 公式と同じく空の allowlist は no-op（全量保持）。oneOf 内の `$ref` 以外の項目や
    /// `#/components/` で始まらない参照は公式同様スキップ（除去）される。
    public static func pruneComponents(
        catalog: StructuredValue,
        allowedComponents: Set<String>
    ) -> StructuredValue {
        guard !allowedComponents.isEmpty,
              case .object(var root) = catalog else { return catalog }

        // 1. components をフィルタ
        if case .object(let components)? = root["components"] {
            root["components"] = .object(OrderedObject(components.filter { allowedComponents.contains($0.key) }))
        }

        // 2. $defs.anyComponent.oneOf から不許可の "#/components/X" 参照を除去
        if case .object(var defs)? = root["$defs"],
           case .object(var anyComponent)? = defs["anyComponent"],
           case .array(let oneOf)? = anyComponent["oneOf"] {
            let prefix = "#/components/"
            let filtered = oneOf.filter { item in
                guard case .object(let dict) = item,
                      case .string(let ref)? = dict["$ref"],
                      ref.hasPrefix(prefix) else {
                    return false  // 公式: 非 $ref / 未知形式はスキップ
                }
                return allowedComponents.contains(String(ref.dropFirst(prefix.count)))
            }
            anyComponent["oneOf"] = .array(filtered)
            defs["anyComponent"] = .object(anyComponent)
            root["$defs"] = .object(defs)
        }

        return .object(root)
    }

    /// 公式 `_with_pruned_messages` 相当: server_to_client をメッセージ allowlist で絞り込む。
    ///
    /// - v0.9+ 形式（`oneOf` + `$defs`）: oneOf を `#/$defs/X` の allowed のみ残し、
    ///   `$defs` を到達可能性 BFS で絞る
    /// - v0.8 形式（`properties` 直下）: `properties` を到達可能性 BFS で絞る
    ///
    /// 公式と同じく空の allowlist は no-op。oneOf 内の `$ref` 以外や `#/$defs/` で
    /// 始まらない参照は除去される。
    public static func pruneMessages(
        serverToClient: StructuredValue,
        allowedMessages: Set<String>
    ) -> StructuredValue {
        guard !allowedMessages.isEmpty,
              case .object(var root) = serverToClient else { return serverToClient }

        if case .array(let oneOf)? = root["oneOf"] {
            // v0.9+: oneOf を allowed の "#/$defs/X" のみ残す（公式: 非該当はすべて除去）
            let filtered = oneOf.filter { item in
                guard case .object(let dict) = item,
                      case .string(let ref)? = dict["$ref"],
                      let name = lastSegment(ofInternalRef: ref) else {
                    return false
                }
                return allowedMessages.contains(name)
            }
            root["oneOf"] = .array(filtered)

            if case .object(let defs)? = root["$defs"] {
                let pruned = pruneByReachability(
                    defs: defs,
                    roots: allowedMessages,
                    internalRefPrefix: "#/$defs/"
                )
                root["$defs"] = .object(pruned)
            }
        } else if case .object(let properties)? = root["properties"] {
            // v0.8: properties 直下がメッセージ
            let pruned = pruneByReachability(
                defs: properties,
                roots: allowedMessages,
                internalRefPrefix: "#/properties/"
            )
            root["properties"] = .object(pruned)
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
        commonTypes: StructuredValue,
        reachableFrom externalSchemas: [StructuredValue]
    ) -> StructuredValue {
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
        root["$defs"] = .object(OrderedObject(defs.filter { visited.contains($0.key) }))
        return .object(root)
    }

    /// JSON 構造の中から全ての `$ref` 値を再帰的に集める。
    public static func collectRefs(in value: StructuredValue) -> Set<String> {
        var refs: Set<String> = []
        collectRefsInternal(value, into: &refs)
        return refs
    }

    // MARK: - Internal

    /// 与えられた `$defs` を、`roots` から `internalRefPrefix` 経由で到達可能なエントリのみに絞る。
    static func pruneByReachability(
        defs: OrderedObject,
        roots: Set<String>,
        internalRefPrefix: String
    ) -> OrderedObject {
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

        return OrderedObject(defs.filter { visited.contains($0.key) })
    }

    private static func collectRefsInternal(_ value: StructuredValue, into refs: inout Set<String>) {
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
