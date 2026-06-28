/// サーバ → クライアント方向の全メッセージをまとめる enum（A2UI v0.10）。
///
/// `version` フィールドはデコード時に検証するが、Postel 則に従い欠落は許容（現行バージョンと仮定）。
/// バージョンが存在しかつ現行と異なる場合のみエラーを投げる。
public enum ServerMessage: Sendable, Equatable {
    case createSurface(CreateSurface)
    case updateComponents(UpdateComponents)
    case updateDataModel(UpdateDataModel)
    case deleteSurface(DeleteSurface)
    /// v0.10: サーバがクライアント上の関数を呼び出す。
    case callFunction(CallFunctionMessage)
    /// v0.10: サーバが応答要求付きのクライアントアクションに答える。
    case actionResponse(ActionResponseMessage)
}

extension ServerMessage: Codable {
    private enum CodingKeys: String, CodingKey {
        case version
        case createSurface
        case updateComponents
        case updateDataModel
        case deleteSurface
        case callFunction
        case actionResponse
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Postel: encode always writes `version`; decode tolerates a missing one (assume current).
        // LLMs occasionally misplace `version` inside the payload — dropping the whole message for
        // that (and failing the turn as "no surface produced") costs a full regeneration round-trip.
        // A present-but-different version is still rejected: that is a genuine incompatibility.
        if let version = try container.decodeIfPresent(String.self, forKey: .version),
           version != A2UIVersion.current {
            throw DecodingError.dataCorruptedError(
                forKey: .version, in: container,
                debugDescription: "Unsupported A2UI version: \(version)"
            )
        }
        if container.contains(.createSurface) {
            self = .createSurface(try container.decode(CreateSurface.self, forKey: .createSurface))
        } else if container.contains(.updateComponents) {
            self = .updateComponents(try container.decode(UpdateComponents.self, forKey: .updateComponents))
        } else if container.contains(.updateDataModel) {
            self = .updateDataModel(try container.decode(UpdateDataModel.self, forKey: .updateDataModel))
        } else if container.contains(.deleteSurface) {
            self = .deleteSurface(try container.decode(DeleteSurface.self, forKey: .deleteSurface))
        } else if container.contains(.callFunction) {
            // Flat message: functionCallId / wantResponse / callFunction are siblings of `version`.
            self = .callFunction(try CallFunctionMessage(from: decoder))
        } else if container.contains(.actionResponse) {
            // Flat message: actionId / actionResponse are siblings of `version`.
            self = .actionResponse(try ActionResponseMessage(from: decoder))
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "No recognized message type key found"
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(A2UIVersion.current, forKey: .version)
        switch self {
        case .createSurface(let msg):
            try container.encode(msg, forKey: .createSurface)
        case .updateComponents(let msg):
            try container.encode(msg, forKey: .updateComponents)
        case .updateDataModel(let msg):
            try container.encode(msg, forKey: .updateDataModel)
        case .deleteSurface(let msg):
            try container.encode(msg, forKey: .deleteSurface)
        case .callFunction(let msg):
            // Flat: write functionCallId / wantResponse / callFunction alongside `version`.
            try msg.encode(to: encoder)
        case .actionResponse(let msg):
            try msg.encode(to: encoder)
        }
    }
}

extension ServerMessage {
    /// 公式 `server_to_client.json` の `$defs` 名（例: `"CreateSurfaceMessage"`）。
    /// `A2UIPromptBuilder(allowedMessages:)` による pruning と生成後バリデーションで
    /// 共通して使う識別子セットであり、プロンプト側の絞り込みと検証が同一の定義を参照することを保証する。
    public var schemaMessageName: String {
        switch self {
        case .createSurface: "CreateSurfaceMessage"
        case .updateComponents: "UpdateComponentsMessage"
        case .updateDataModel: "UpdateDataModelMessage"
        case .deleteSurface: "DeleteSurfaceMessage"
        case .callFunction: "CallFunctionMessage"
        case .actionResponse: "ActionResponseMessage"
        }
    }
}
