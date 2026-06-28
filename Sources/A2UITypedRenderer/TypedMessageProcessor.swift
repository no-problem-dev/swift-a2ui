import Foundation
import A2UICore
import A2UISurface
import A2UITyped

/// A2UI `ServerMessage` を型付きサーフェス群に適用するプロセッサ —
/// `A2UISurface.MessageProcessor` の型付き版で `SurfaceModel` の代わりに
/// `TypedSurface<Catalog>` を生成する。
///
/// ホスト（Studio アプリ等）はエージェントの `<a2ui-json>` を `[ServerMessage]` へパースして
/// ここへ渡す。`surfaces` は `A2UISurfaceView` でレンダリングする。ユーザーアクションは
/// `onAction` として `UserAction` に変換されて返り、旧プロセッサとの互換性を保つ。
@MainActor
@Observable
public final class TypedMessageProcessor<Catalog: A2UICatalog> {
    public private(set) var surfaces: [String: TypedSurface<Catalog>] = [:]

    /// 作成順に並んだサーフェス ID。新しいサーフェスが ID ソート順でなく末尾に追加されるよう
    /// ページング / スタック表示を駆動する。
    private var creationOrder: [String] = []

    /// ホストのユーザーアクションシンク（Button イベント等）。`MessageProcessor.onAction` に対応。
    public var onAction: (UserAction) -> Void

    public init(onAction: @escaping (UserAction) -> Void = { _ in }) {
        self.onAction = onAction
    }

    /// 作成順のサーフェス配列（`ForEach` / ページング用）。作成記録より前に存在するサーフェスは
    /// id ソートにフォールバックする（防御的処理。通常は全サーフェスが作成時に記録される）。
    public var ordered: [TypedSurface<Catalog>] {
        creationOrder.compactMap { surfaces[$0] }
    }

    public func process(_ messages: [ServerMessage]) {
        for message in messages { process(message) }
    }

    public func process(_ message: ServerMessage) {
        switch message {
        case .createSurface(let cs):
            // v0.10: createSurface may carry the initial tree and data model inline.
            // The official eval validator treats these as exactly equivalent to a
            // following updateComponents / root updateDataModel, so they flow through
            // the same apply functions. Data model first: bindings resolve by the
            // time the root component appears.
            let surface = makeSurface(id: cs.surfaceId)
            surfaces[cs.surfaceId] = surface
            record(cs.surfaceId)
            if let dataModel = cs.dataModel {
                surface.applyUpdateDataModel(path: "", value: dataModel)
            }
            if let components = cs.components {
                surface.applyUpdateComponents(components.map { CatalogNode<Catalog.Node>.lenientDecode($0) })
            }
        case .updateComponents(let uc):
            let surface = surfaces[uc.surfaceId] ?? makeSurface(id: uc.surfaceId)
            surfaces[uc.surfaceId] = surface
            record(uc.surfaceId)
            // Lenient: a malformed known component degrades to an `.unknown` placeholder instead of
            // silently disappearing, so partial/invalid LLM output renders a visible marker.
            let nodes = uc.components.map { CatalogNode<Catalog.Node>.lenientDecode($0) }
            surface.applyUpdateComponents(nodes)
        case .updateDataModel(let udm):
            let surface = surfaces[udm.surfaceId] ?? makeSurface(id: udm.surfaceId)
            surfaces[udm.surfaceId] = surface
            record(udm.surfaceId)
            surface.applyUpdateDataModel(path: udm.path ?? "", value: udm.value)
        case .deleteSurface(let ds):
            surfaces.removeValue(forKey: ds.surfaceId)
            creationOrder.removeAll { $0 == ds.surfaceId }
        case .callFunction, .actionResponse:
            // v0.10 server-initiated RPC / action responses are handled by the host, not the
            // surface store (they don't mutate the component tree directly).
            break
        }
    }

    public func removeAll() {
        surfaces.removeAll()
        creationOrder.removeAll()
    }

    /// 初回確認時にサーフェス id を作成順リストへ追加する。
    private func record(_ id: String) {
        if !creationOrder.contains(id) { creationOrder.append(id) }
    }

    private func makeSurface(id: String) -> TypedSurface<Catalog> {
        TypedSurface(id: id, rootId: "root", nodes: []) { [weak self] name, context, sourceComponentId in
            self?.onAction(UserAction(
                name: name,
                surfaceId: id,
                sourceComponentId: sourceComponentId,
                timestamp: ISO8601DateFormatter().string(from: Date()),
                context: context
            ))
        }
    }
}
