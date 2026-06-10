import A2ACore
import A2UICore

/// A2A のストリーム/パートから A2UI サーバメッセージを取り出すヘルパ
/// （Python SDK の a2ui 抽出に相当）。オーケストレータが side-channel で
/// ワーカーの A2UI 出力を描画系へ流す際の公式相当 API。
extension Sequence where Element == Part {
    /// このパート列に含まれる A2UI サーバメッセージを取り出す。
    /// A2UI でないパートは無視し、A2UI を名乗るが壊れているパートも握りつぶす
    /// （描画/ルーティングを止めないための寛容な抽出）。
    public func a2uiServerMessages() -> [ServerMessage] {
        compactMap { try? $0.a2uiServerMessage() }
    }

    /// A2UI を含むか。
    public var containsA2UI: Bool {
        contains(where: \.isA2UI)
    }
}

extension StreamResponse {
    /// このストリームイベントのペイロードから A2UI サーバメッセージを取り出す。
    public func a2uiServerMessages() -> [ServerMessage] {
        parts.a2uiServerMessages()
    }

    /// このストリームイベントが A2UI を含むか。
    public var containsA2UI: Bool {
        parts.containsA2UI
    }
}
