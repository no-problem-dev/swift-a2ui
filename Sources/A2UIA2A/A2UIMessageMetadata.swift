import StructuredDataCore
import A2ACore
import A2UICore

/// クライアントがレンダリングできる情報: 対応カタログ ID とオプションのインラインカタログ。
/// カタログネゴシエーションが LLM プロンプトに入らないよう `Message.metadata` で伝達する。
public struct A2UIRendererCapabilities: Codable, Sendable, Equatable {
    public var supportedCatalogIds: [String]
    /// インラインカタログを受け入れるエージェント向けのカタログ定義一式（生カタログ JSON）。
    public var inlineCatalogs: [StructuredValue]?

    public init(supportedCatalogIds: [String] = [], inlineCatalogs: [StructuredValue]? = nil) {
        self.supportedCatalogIds = supportedCatalogIds
        self.inlineCatalogs = inlineCatalogs
    }
}

/// サーフェスごとのクライアント側データモデルのスナップショット。オーケストレータは
/// 対象エージェントが所有するサーフェスのみを転送する（公式サンプルの "Data Model Stripping"）。
public struct A2UIRendererDataModel: Codable, Sendable, Equatable {
    /// プロトコルバージョン。v1.0 の `renderer_data_model.json` は `surfaces` と並ぶ平坦な項目
    /// として持つ（capabilities のようにバージョンキーで包まない）。
    public var version: String
    public var surfaces: [String: StructuredValue]

    public init(surfaces: [String: StructuredValue] = [:], version: String = A2UIVersion.current) {
        self.version = version
        self.surfaces = surfaces
    }

    /// 指定サーフェスのみを残したコピーを返す — ストリッピングの基本操作。
    /// どのエージェントがどのサーフェスを見てよいかは呼び出し元の知識。
    public func keeping(_ surfaceIds: some Sequence<String>) -> A2UIRendererDataModel {
        let kept = Set(surfaceIds)
        return A2UIRendererDataModel(surfaces: surfaces.filter { kept.contains($0.key) })
    }
}

/// A2UI 語彙の `Message.metadata` キーと型付きアクセサ
/// （公式オーケストレータのメタデータ処理のミラー）。
public enum A2UIMessageMetadata {
    /// 公式 `A2UI_CLIENT_CAPABILITIES_KEY`。
    public static let rendererCapabilitiesKey = "a2uiRendererCapabilities"
    /// 公式 `a2uiRendererDataModel` キー。
    public static let rendererDataModelKey = "a2uiRendererDataModel"

    /// v1.0: capabilities はバージョンキー配下に入れ子になる
    /// （`{"a2uiRendererCapabilities": {"v1.0": {"supportedCatalogIds": […]}}}`）。
    public static func rendererCapabilities(in metadata: A2AMetadata?) -> A2UIRendererCapabilities? {
        guard let envelope = metadata?[rendererCapabilitiesKey] else { return nil }
        // 現行バージョンのブロックを読む。無ければ入れ子でない旧形として解釈を試みる。
        if let versioned = try? envelope[A2UIVersion.current].decode(A2UIRendererCapabilities.self),
           !versioned.supportedCatalogIds.isEmpty || versioned.inlineCatalogs != nil {
            return versioned
        }
        return try? envelope.decode(A2UIRendererCapabilities.self)
    }

    public static func rendererDataModel(in metadata: A2AMetadata?) -> A2UIRendererDataModel? {
        metadata?[rendererDataModelKey].flatMap { try? $0.decode(A2UIRendererDataModel.self) }
    }

    public static func embed(_ capabilities: A2UIRendererCapabilities, into metadata: inout A2AMetadata) throws {
        metadata[rendererCapabilitiesKey] = .object([A2UIVersion.current: try .encoded(capabilities)])
    }

    public static func embed(_ dataModel: A2UIRendererDataModel, into metadata: inout A2AMetadata) throws {
        metadata[rendererDataModelKey] = try .encoded(dataModel)
    }
}
