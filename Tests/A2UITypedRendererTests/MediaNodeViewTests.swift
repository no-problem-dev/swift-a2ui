import Testing
import Foundation
import SwiftUI
import A2UICore
import A2UICatalog
import A2UISurface
@testable import A2UITyped
@testable import A2UITypedRenderer

@MainActor
@Suite("Media viewer: Video/AudioPlayer surface + environment opt-out")
struct MediaNodeViewTests {
    private func makeSurface() throws -> TypedSurface<BasicCatalog> {
        let componentsJSON = """
        [
          {"id":"root","component":"Column","children":["v1","a1","img"]},
          {"id":"v1","component":"Video","url":"https://example.com/movie.mp4"},
          {"id":"a1","component":"AudioPlayer","url":"https://example.com/voice.m4a"},
          {"id":"img","component":"Image","url":"https://example.com/photo.jpg"}
        ]
        """
        let nodes = try TypedSurface<BasicCatalog>.decodeNodes(fromJSONArray: Data(componentsJSON.utf8))
        return TypedSurface(rootId: "root", nodes: nodes)
    }

    @Test("Video / AudioPlayer / Image を含むサーフェスがデコードできる")
    func decodesMediaSurface() throws {
        let surface = try makeSurface()
        guard case .known(.video(let video)) = surface.node("v1") else {
            Issue.record("v1 should be a known Video node"); return
        }
        guard case .known(.audioPlayer) = surface.node("a1") else {
            Issue.record("a1 should be a known AudioPlayer node"); return
        }
        guard case .known(.image) = surface.node("img") else {
            Issue.record("img should be a known Image node"); return
        }
        let ctx = RenderContext(surface: surface, scope: "")
        #expect(ctx.resolve(video.url) == "https://example.com/movie.mp4")
    }

    @Test("メディアを含むサーフェスビューが型チェックを通る（zero erasure）")
    func mediaSurfaceViewCompiles() throws {
        let surface = try makeSurface()
        _ = A2UISurfaceView(surface)
    }

    @Test("a2uiMediaViewerEnabled のデフォルトは有効")
    func mediaViewerEnabledByDefault() {
        let environment = EnvironmentValues()
        #expect(environment.a2uiMediaViewerEnabled == true)
    }

    @Test("a2uiMediaViewer(_:) モディファイアが適用できる")
    func optOutModifierCompiles() throws {
        let surface = try makeSurface()
        _ = A2UISurfaceView(surface).a2uiMediaViewer(false)
    }
}
