import A2UICore

/// カタログの `Known` ノード型に A2UI が定める unknown コンポーネント処理を追加するラッパー。
///
/// レンダラーが異なる対応を取るべき 2 つのケースを型レベルで分離する:
///
/// - **カタログミス**（`component` 名が `Known.componentNames` に存在しない）: エージェントがこのクライアントに
///   存在しないコンポーネントをリクエストした。A2UI renderer guide に従いグレースフルデグラデーション
///   （プレースホルダー表示/スキップ、クラッシュなし）が必要。名前・生データを保持する `.unknown` ケースで表現する。
/// - **構造的障害**（名前は既知だがプロパティが不正）: 正規のバリデーションエラー。
///   `Known(from:)` は `throw` を許可し、デコードパイプラインがエラーをエージェントへのフィードバックとして伝搬する
///   （仕様の prompt→generate→validate ループ）。
public enum CatalogNode<Known: ComponentNode>: Decodable, Sendable, Equatable {
    case known(Known)
    case unknown(name: String, id: ComponentId, raw: StructuredValue)

    private enum Keys: String, CodingKey { case component, id }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        let name = try container.decode(String.self, forKey: .component)
        if Known.componentNames.contains(name) {
            // Known name → decode strictly. A throw here is a validation error, not an unknown.
            self = .known(try Known(from: decoder))
        } else {
            let id = try container.decodeIfPresent(ComponentId.self, forKey: .id) ?? ""
            self = .unknown(name: name, id: id, raw: try StructuredValue(from: decoder))
        }
    }

    /// 寛容デコード: 既知の名前でもプロパティ不正の場合に `throw` せず `.unknown` プレースホルダーに降格する。
    /// ライブメッセージプロセッサで使用し、1 つの不正コンポーネントがサーフェス全体の描画を妨げないようにする。
    /// 問題箇所は "Not Supported" マーカーとして表示され診断可能なまま残る。
    public static func lenientDecode(_ value: StructuredValue) -> CatalogNode<Known> {
        if let node = try? value.decode(CatalogNode<Known>.self) {
            return node
        }
        let probe = try? value.decode(Probe.self)
        return .unknown(name: probe?.component ?? "Unknown", id: probe?.id ?? "", raw: value)
    }

    private struct Probe: Decodable { let component: String?; let id: String? }

    /// コンポーネントインスタンスの id（どちらのケースも保持）。unknown コンポーネントもワイヤー上に id を持つ。
    public var id: ComponentId {
        switch self {
        case .known(let node): return node.id
        case .unknown(_, let id, _): return id
        }
    }

    /// ワイヤー上の `component` ディスクリミネータ（unknown の場合は名前をそのまま保持）。
    public var componentName: String {
        switch self {
        case .known(let node): return node.componentName
        case .unknown(let name, _, _): return name
        }
    }
}
