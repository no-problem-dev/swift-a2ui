import A2UICore

/// コンポーネントのトポロジーと ID 一意性を検証する。
public enum ComponentValidator {

    /// バリデーションエラー。
    public enum ValidationError: Error, Sendable, Equatable {
        /// 同一 id を持つコンポーネントが複数存在する。
        case duplicateId(String)
        /// id "root" のコンポーネントが存在しない。
        case missingRoot
        /// コンポーネントの循環参照を検出した。
        case circularReference(String)
        /// ツリーの深さが上限を超過した。
        case depthLimitExceeded
    }

    /// ツリーリゾルバーを使ってコンポーネントのトポロジーを検証する。
    /// root 欠如・循環参照・深度超過を検出する。
    public static func validateTopology(components: [String: StructuredValue]) throws {
        guard components["root"] != nil else {
            throw ValidationError.missingRoot
        }

        do {
            _ = try ComponentTreeResolver.resolve(components: components)
        } catch ComponentTreeResolver.TreeError.circularReference(let id) {
            throw ValidationError.circularReference(id)
        } catch ComponentTreeResolver.TreeError.depthLimitExceeded {
            throw ValidationError.depthLimitExceeded
        } catch ComponentTreeResolver.TreeError.missingRoot {
            throw ValidationError.missingRoot
        }
    }

    /// フラットな `StructuredValue` 配列内のすべてのコンポーネント ID が一意であることを検証する。
    /// 各要素は "id" 文字列フィールドを持つオブジェクトであることを前提とする。
    public static func validateUniqueIds(components: [StructuredValue]) throws {
        var seen: Set<String> = []
        for component in components {
            if case .object(let dict) = component,
               case .string(let id) = dict["id"] {
                if seen.contains(id) {
                    throw ValidationError.duplicateId(id)
                }
                seen.insert(id)
            }
        }
    }
}
