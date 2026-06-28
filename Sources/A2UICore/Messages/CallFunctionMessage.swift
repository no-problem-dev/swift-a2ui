/// サーバ → クライアントの関数呼び出しリクエスト（A2UI v0.10）。
///
/// `functionCallId` は対応する `FunctionResponse`（または `error`）にそのまま複写する必要がある。
/// `callFunction.callableFrom` は `remoteOnly` または `clientOrRemote` でなければならない
/// （サーバは `clientOnly` 関数を呼び出せない）。ワイヤー上ではこれらのフィールドは
/// `version` と同じメッセージ最上位に並ぶ。
public struct CallFunctionMessage: Codable, Sendable, Equatable {
    public let functionCallId: CallId
    public let wantResponse: Bool?
    public let callFunction: FunctionCall

    public init(functionCallId: CallId, callFunction: FunctionCall, wantResponse: Bool? = nil) {
        self.functionCallId = functionCallId
        self.callFunction = callFunction
        self.wantResponse = wantResponse
    }
}

/// `wantResponse: true` を設定したクライアントアクションへのサーバ応答メッセージ（A2UI v0.10）。
///
/// `actionId` は発信元の `action` と対応付ける。クライアントはアクションの `responsePath`
/// （存在する場合）に値をローカルデータモデルへ書き込む。ワイヤー上では `version` と同じ最上位に並ぶ。
public struct ActionResponseMessage: Codable, Sendable, Equatable {
    public let actionId: String
    public let actionResponse: ActionResponse

    public init(actionId: String, actionResponse: ActionResponse) {
        self.actionId = actionId
        self.actionResponse = actionResponse
    }
}

/// `ActionResponseMessage` のペイロード: 戻り値（`value`）またはエラー（`error`）。
public enum ActionResponse: Sendable, Equatable {
    case value(StructuredValue)
    case error(code: String, message: String)
}

extension ActionResponse: Codable {
    private enum CodingKeys: String, CodingKey { case value, error }
    private struct ErrorBody: Codable, Equatable { let code: String; let message: String }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.error) {
            let body = try container.decode(ErrorBody.self, forKey: .error)
            self = .error(code: body.code, message: body.message)
        } else {
            self = .value(try container.decode(StructuredValue.self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .value(let v):
            try container.encode(v, forKey: .value)
        case .error(let code, let message):
            try container.encode(ErrorBody(code: code, message: message), forKey: .error)
        }
    }
}
