/// システムプロンプト向けのフューショット例をマーカー形式に整形する —
/// 公式 Python `A2uiCatalog.load_examples()` のマーカー形式に対応する Swift 版。
/// ワークフロープロンプトはこれらのマーカーで例を参照する（例: "Use the JSON from `---BEGIN chart---`"）。
public enum A2UIExampleFormatter {

    /// 一つの例を `---BEGIN {name}---` / `---END {name}---` マーカーで囲む。
    public static func format(name: String, content: String) -> String {
        "---BEGIN \(name)---\n\(content)\n---END \(name)---"
    }

    /// 複数の名前付き例を空行区切りで結合する（Python は `\n\n` で結合）。
    public static func merge(_ examples: [(name: String, content: String)]) -> String {
        examples.map { format(name: $0.name, content: $0.content) }.joined(separator: "\n\n")
    }
}
