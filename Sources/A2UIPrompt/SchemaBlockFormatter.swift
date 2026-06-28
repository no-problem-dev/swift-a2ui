/// 3 つの JSON スキーマ文字列を公式の A2UI スキーマブロック形式に整形する。
///
/// ブロックは `---BEGIN A2UI JSON SCHEMA---` と `---END A2UI JSON SCHEMA---` で囲み、
/// 各スキーマはラベル付きの行に配置する — Python SDK の出力と完全に一致する形式。
public enum SchemaBlockFormatter {
    /// スキーマブロックの開始デリミタ。
    public static let beginMarker = "---BEGIN A2UI JSON SCHEMA---"
    /// スキーマブロックの終了デリミタ。
    public static let endMarker = "---END A2UI JSON SCHEMA---"

    /// 3 つのスキーマを公式スキーマブロック形式の文字列に組み立てる。
    ///
    /// - Parameters:
    ///   - serverToClientSchema: サーバ → クライアントスキーマの JSON 文字列。
    ///   - commonTypesSchema: 共通型スキーマの JSON 文字列。
    ///   - catalogSchema: コンポーネントカタログスキーマの JSON 文字列。
    /// - Returns: 公式 A2UI スキーマブロック形式の複数行文字列。
    public static func format(
        serverToClientSchema: String,
        commonTypesSchema: String,
        catalogSchema: String
    ) -> String {
        var sections: [String] = [beginMarker]
        sections.append("### Server To Client Schema:\n\(serverToClientSchema)")
        if !commonTypesSchema.isEmpty, commonTypesSchema != "{}" {
            sections.append("### Common Types Schema:\n\(commonTypesSchema)")
        }
        sections.append("### Catalog Schema:\n\(catalogSchema)")
        sections.append(endMarker)
        return sections.joined(separator: "\n\n")
    }
}
