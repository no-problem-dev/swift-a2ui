/// サーフェス上のコンポーネントを差し替え・挿入するメッセージ（A2UI v0.10）。
///
/// カタログ非依存: 型付きデコードは `A2UICatalog` 側で行う。
public struct UpdateComponents: Codable, Sendable, Equatable {
    public let surfaceId: String
    public let components: [StructuredValue]

    public init(surfaceId: String, components: [StructuredValue]) {
        self.surfaceId = surfaceId
        self.components = components
    }
}
