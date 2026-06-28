import A2ACore
import A2UICore
import A2UIA2A

/// どのエージェントがどのサーフェスを所有するかを管理する会話スコープ台帳。
/// 決定論的 userAction ルーティングとデータモデルストリッピングの両方の基盤
/// （公式サンプルの `SubagentRouteManager` に相当。公式はステートレスなアクセサペアを ADK セッション状態上に
/// 持つが、こちらはホストセッションが所有する値型の台帳）。
///
/// 書き込み 1 つ、読み取り 2 つ:
/// - サブエージェントのレスポンスがサーフェスを生成した際に書き込む（`record(surfacesCreatedIn:by:)`）
/// - LLM 呼び出しなしに userAction を所有者へルーティングする際に読む（`owner(ofUserActionIn:)`）
/// - クライアントデータモデルを対象エージェントが見てよいスコープに絞る際に読む（`outboundMetadata`）
public struct SurfaceOwnership: Sendable, Equatable {
    private var owners: [String: String] = [:]

    public init() {}

    public func owner(of surfaceId: String) -> String? {
        owners[surfaceId]
    }

    /// 後着優先で上書きする。公式 `set_route_to_subagent_name` の上書きセマンティクスに一致する。
    public mutating func record(owner agent: String, of surfaceId: String) {
        owners[surfaceId] = agent
    }

    public func surfaceIds(ownedBy agent: String) -> Set<String> {
        Set(owners.filter { $0.value == agent }.keys)
    }
}

// MARK: - Recording (mirror of the official agent_executor's event observation)

extension SurfaceOwnership {
    /// `parts` 内で生成されたすべてのサーフェスの所有者として `agent` を記録する。
    ///
    /// 公式サンプルは各アウトバウンドサブエージェントイベントで `beginRendering` を観測する。
    /// v0.10 のサーフェス生成メッセージは `createSurface`。サブエージェントから受け取った
    /// パートのバッチごとに、サブエージェントの名前（公式の `event.author`）を `agent` として呼び出す。
    public mutating func record(surfacesCreatedIn parts: [Part], by agent: String) {
        for part in parts {
            guard case .createSurface(let creation)? = try? part.a2uiServerMessage() else { continue }
            record(owner: agent, of: creation.surfaceId)
        }
    }
}

// MARK: - Deterministic routing (mirror of the official before_model_callback)

extension SurfaceOwnership {
    /// メッセージを LLM 呼び出しなしにルーティングするエージェント名。不明なサーフェスや
    /// 読み取れないアクションの場合は `nil` を返し LLM ルーティングにフォールバックする。
    ///
    /// 公式 `programmtically_route_user_action_to_subagent` と同様、末尾パーツのみを対象とする。
    /// 決定論的ルーティングは最適化であり、正確性のゲートではない。
    public func owner(ofUserActionIn parts: [Part]) -> String? {
        guard let action = parts.last?.a2uiUserAction else { return nil }
        return owner(of: action.surfaceId)
    }
}

// MARK: - Outbound metadata (mirror of the official A2UIMetadataInterceptor)

extension SurfaceOwnership {
    /// `agent` に送信するメッセージメタデータを準備する: クライアントケイパビリティを埋め込み、
    /// クライアントデータモデルをそのエージェントが所有するサーフェスに絞る
    /// （公式の "Data Model Stripping to prevent data leakage" — エージェントは他のエージェントの
    /// サーフェスデータを参照できない）。
    ///
    /// データモデルが存在すれば常にストリッピングを適用する（サーフェスセットが空の場合も含む）。
    /// 公式インターセプターの動作に一致する。
    public func outboundMetadata(
        _ metadata: A2AMetadata?,
        capabilities: A2UIClientCapabilities?,
        for agent: String
    ) throws -> A2AMetadata? {
        var result = metadata ?? [:]
        if let capabilities {
            try A2UIMessageMetadata.embed(capabilities, into: &result)
        }
        if let dataModel = A2UIMessageMetadata.clientDataModel(in: result) {
            try A2UIMessageMetadata.embed(dataModel.keeping(surfaceIds(ownedBy: agent)), into: &result)
        }
        return result.isEmpty ? nil : result
    }
}
