import Testing
import SwiftUI
import AppKit
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import A2UICore
import A2UICatalog
import A2UISurface
@testable import A2UITyped
@testable import A2UITypedRenderer

/// Golden render tests for the typed renderer.
///
/// Earlier in the migration this suite compared the new renderer pixel-for-pixel against the old
/// `A2UIRenderer.SurfaceView` and proved them identical (perceptible diff < 0.0001 for the card and
/// route-card corpora). The old renderer has since been deleted, so this keeps the new path under a
/// determinism + non-blank guard, and dumps PNGs to /tmp for manual inspection.
@MainActor
@Suite("Typed renderer golden render")
struct ParityTests {
    static let canvas = CGSize(width: 375, height: 700)

    private func messages(_ json: String) throws -> [ServerMessage] {
        try JSONDecoder().decode([ServerMessage].self, from: Data(json.utf8))
    }

    private func surface(_ json: String) throws -> TypedSurface<BasicCatalog> {
        var components: [StructuredValue] = []
        let dataModel = DataModel()
        for message in try messages(json) {
            switch message {
            case .createSurface: break
            case .updateComponents(let uc): components += uc.components
            case .updateDataModel(let udm): dataModel.set(udm.path ?? "", udm.value)
            default: break
            }
        }
        let nodes = try components.map { try $0.decode(CatalogNode<BasicComponent>.self) }
        return TypedSurface(rootId: "root", nodes: nodes, dataModel: dataModel)
    }

    /// Rasterize via `NSHostingView` in an offscreen window so the full SwiftUI lifecycle runs.
    private func rasterize(_ view: some View) -> CGImage? {
        let sized = AnyView(view.frame(
            width: Self.canvas.width, height: Self.canvas.height, alignment: .topLeading))
        let host = NSHostingView(rootView: sized)
        host.frame = CGRect(origin: .zero, size: Self.canvas)
        let window = NSWindow(
            contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.15))
        defer { window.orderOut(nil) }
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return nil }
        host.cacheDisplay(in: host.bounds, to: rep)
        return rep.cgImage
    }

    private func pixels(_ image: CGImage) -> [UInt8] {
        let w = image.width, h = image.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        let ctx = CGContext(
            data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        ctx?.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return data
    }

    private func diffRatio(_ a: CGImage, _ b: CGImage) -> Double {
        guard a.width == b.width, a.height == b.height else { return 1 }
        let pa = pixels(a), pb = pixels(b)
        var differing = 0
        for i in stride(from: 0, to: pa.count, by: 4) where
            pa[i] != pb[i] || pa[i + 1] != pb[i + 1] || pa[i + 2] != pb[i + 2] {
            differing += 1
        }
        return Double(differing) / Double(a.width * a.height)
    }

    /// Count of "content" (dark/non-background) pixels — proves the surface rendered real content.
    private func contentPixels(_ image: CGImage) -> Int {
        let p = pixels(image)
        var count = 0
        for i in stride(from: 0, to: p.count, by: 4) where max(p[i], p[i + 1], p[i + 2]) < 160 { count += 1 }
        return count
    }

    private func writePNG(_ image: CGImage, _ path: String) {
        guard let dest = CGImageDestinationCreateWithURL(
            URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }

    static let cardCorpus = """
    [
      {"version":"v0.9","createSurface":{"surfaceId":"s1","catalogId":"basic"}},
      {"version":"v0.9","updateComponents":{"surfaceId":"s1","components":[
        {"id":"root","component":"Card","child":"col"},
        {"id":"col","component":"Column","children":["t1","d1","t2"]},
        {"id":"t1","component":"Text","text":"見出し","variant":"h3"},
        {"id":"d1","component":"Divider"},
        {"id":"t2","component":"Text","text":"本文テキスト。"}
      ]}}
    ]
    """

    static let richCorpus = """
    [
      {"version":"v0.9","createSurface":{"surfaceId":"s1","catalogId":"basic"}},
      {"version":"v0.9","updateComponents":{"surfaceId":"s1","components":[
        {"id":"root","component":"Card","child":"col"},
        {"id":"col","component":"Column","children":["header","summary","div1","list1","div2","actions"]},
        {"id":"header","component":"Row","align":"center","children":["hicon","htitle"]},
        {"id":"hicon","component":"Icon","name":"train"},
        {"id":"htitle","component":"Text","text":"乗換案内: 反町 → 六本木一丁目","variant":"h3"},
        {"id":"summary","component":"Row","justify":"spaceEvenly","children":["s1c","s2c","s3c"]},
        {"id":"s1c","component":"Column","align":"center","children":["s1l","s1v"]},
        {"id":"s1l","component":"Text","text":"所要時間","variant":"caption"},
        {"id":"s1v","component":"Text","text":"約50分","variant":"h4"},
        {"id":"s2c","component":"Column","align":"center","children":["s2l","s2v"]},
        {"id":"s2l","component":"Text","text":"運賃","variant":"caption"},
        {"id":"s2v","component":"Text","text":"487円","variant":"h4"},
        {"id":"s3c","component":"Column","align":"center","children":["s3l","s3v"]},
        {"id":"s3l","component":"Text","text":"乗換","variant":"caption"},
        {"id":"s3v","component":"Text","text":"1回","variant":"h4"},
        {"id":"div1","component":"Divider"},
        {"id":"list1","component":"List","children":["step1","step2"]},
        {"id":"step1","component":"Row","align":"center","children":["d1","st1c"]},
        {"id":"d1","component":"Icon","name":"locationOn"},
        {"id":"st1c","component":"Column","children":["st1s","st1l"]},
        {"id":"st1s","component":"Text","text":"反町駅","variant":"body"},
        {"id":"st1l","component":"Text","text":"東急東横線 (各停) に乗車","variant":"caption"},
        {"id":"step2","component":"Row","align":"center","children":["d2","st2c"]},
        {"id":"d2","component":"Icon","name":"check"},
        {"id":"st2c","component":"Column","children":["st2s","st2l"]},
        {"id":"st2s","component":"Text","text":"六本木一丁目駅","variant":"body"},
        {"id":"st2l","component":"Text","text":"約34分で到着","variant":"caption"},
        {"id":"div2","component":"Divider"},
        {"id":"actions","component":"Row","justify":"start","children":["btnA","btnB"]},
        {"id":"btnA","component":"Button","variant":"primary","child":"btnAt","action":{"event":{"name":"search"}}},
        {"id":"btnAt","component":"Text","text":"検索"},
        {"id":"btnB","component":"Button","variant":"borderless","child":"btnBt","action":{"event":{"name":"alt"}}},
        {"id":"btnBt","component":"Text","text":"別ルート"}
      ]}}
    ]
    """

    @Test("typed renderer is deterministic (same surface → identical pixels)")
    func deterministic() throws {
        let a = try #require(rasterize(A2UISurfaceView(try surface(Self.cardCorpus))))
        let b = try #require(rasterize(A2UISurfaceView(try surface(Self.cardCorpus))))
        #expect(diffRatio(a, b) == 0)
    }

    @Test("card renders real content")
    func cardRenders() throws {
        let img = try #require(rasterize(A2UISurfaceView(try surface(Self.cardCorpus))))
        writePNG(img, "/tmp/typed_card.png")
        #expect(contentPixels(img) > 500)
    }

    @Test("route card renders real content")
    func richRenders() throws {
        let img = try #require(rasterize(A2UISurfaceView(try surface(Self.richCorpus))))
        writePNG(img, "/tmp/typed_rich.png")
        #expect(contentPixels(img) > 2000)
    }
}
