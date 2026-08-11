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

/// Everything the renderer itself puts on screen — as opposed to what the agent wrote — has to
/// follow the consumer's locale. These were Japanese literals, so an English-locale host rendered
/// Japanese with no way to change it.
@Suite("The renderer's own text follows the host's locale")
struct RendererStringsLocalizationTests {

    @Test func englishHostSeesEnglish() throws {
        let english = try #require(RendererStrings.bundle(forLanguage: "en"))
        #expect(RendererStrings.generatingUI(english) == "Generating UI…")
        #expect(RendererStrings.busy(english) == "Working")
        #expect(RendererStrings.untitledMedia(english) == "Media")
    }

    /// The Japanese wording is kept as a translation rather than deleted, so a Japanese-locale host
    /// reads exactly what it read before this became localizable at all.
    @Test func japaneseHostStillSeesJapanese() throws {
        let japanese = try #require(RendererStrings.bundle(forLanguage: "ja"))
        #expect(RendererStrings.generatingUI(japanese) == "UI を生成中…")
        #expect(RendererStrings.busy(japanese) == "実行中")
        #expect(RendererStrings.untitledMedia(japanese) == "メディア")
    }

    /// No Japanese literal may creep back into a view. The strings table is the only place that
    /// language belongs.
    @Test func noJapaneseLiteralsLeftInTheRenderer() throws {
        let sources = ["Rendering.swift", "BasicCatalog+Render.swift", "BasicCatalog+Inputs.swift",
                       "TypedSurface.swift", "LayoutMappings.swift", "FlexRowLayout.swift",
                       "TypedMessageProcessor.swift", "MediaViewerEnvironment.swift"]
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/A2UITypedRenderer")
        for name in sources {
            let text = try String(contentsOf: root.appendingPathComponent(name), encoding: .utf8)
            for (offset, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let code = line.contains("//") ? String(line[..<line.range(of: "//")!.lowerBound]) : String(line)
                let japanese = code.unicodeScalars.filter {
                    (0x3040...0x309F).contains($0.value) || (0x30A0...0x30FF).contains($0.value)
                        || (0x4E00...0x9FFF).contains($0.value)
                }
                #expect(japanese.isEmpty, "\(name):\(offset + 1) has a Japanese literal in code")
            }
        }
    }
}
