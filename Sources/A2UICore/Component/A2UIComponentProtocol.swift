/// サーフェス上のコンポーネントインスタンスを一意に識別する文字列キー（JSON Pointer ルート）。
public typealias ComponentId = String

/// 全 A2UI コンポーネント struct が準拠する基底プロトコル。
///
/// `componentName` はワイヤー上の判別子（例: `"Button"`）。`id` はサーフェス内の識別子で、
/// 更新処理とデータバインディングのスコープに使用する。
public protocol A2UIComponentProtocol: Codable, Sendable, Equatable {
    static var componentName: String { get }
    var id: ComponentId { get }
    var accessibility: AccessibilityAttributes? { get }
    var weight: Double? { get }
}
