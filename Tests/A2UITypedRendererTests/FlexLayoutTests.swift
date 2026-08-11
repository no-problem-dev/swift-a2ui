import StructuredDataCore
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

/// FlexDistribution の純粋計算テスト。レンダラーを起動せず flex 意味論だけを検証する。
@Suite("FlexDistribution")
struct FlexDistributionTests {

    /// 回帰: ios-recorder capture 79EC966D。長文 Column 2 つ(weight 1:1)が
    /// spaceBetween Row に入ったとき、画面幅を等分し合計が提案幅を超えないこと。
    /// 旧実装は 2 番目の子を fixedSize にして intrinsic 1 行幅(数千pt)まで膨張させていた。
    @Test func equalWeightsSplitAvailableWidth() {
        let slots = FlexDistribution.compute(
            ideals: [362, 362], weights: [1, 1], available: 370, spacing: 8, justify: .spaceBetween)
        #expect(slots.map(\.width) == [181, 181])
        #expect(slots[1].x + slots[1].width <= 370)
    }

    /// 公式 example 33_financial-data-grid: weight 2 / 1 / 1 / 1.5 の比例配分。
    @Test func proportionalWeights() {
        let slots = FlexDistribution.compute(
            ideals: [0, 0, 0, 0], weights: [2, 1, 1, 1.5], available: 550, spacing: 0, justify: nil)
        #expect(slots.map(\.width) == [200, 100, 100, 150])
    }

    /// weight 2 : 1 が実際に 2 : 1 になる。
    ///
    /// `proportionalWeights` は ideal 0 を渡しているので、この欠陥を隠していた。実際の子
    /// (Column / List はどれも `maxWidth: .infinity`) は提案された幅をそのまま ideal として返す
    /// ので、旧実装では ideal 合計が content を必ず超え、縮小で余白を食い尽くし、weight ループに
    /// 届く leftover が 0 になって重みが無効化されていた。
    @Test func weightsSurviveChildrenThatFillTheirProposal() {
        let slots = FlexDistribution.compute(
            ideals: [370, 370], weights: [2, 1], available: 370, spacing: 10, justify: nil)
        #expect(slots.map(\.width) == [240, 120])
        #expect(slots[1].x + slots[1].width == 370)
    }

    /// weight 付きの子は、weight なしの子が取った残りを weight 比で分ける (CSS `flex: N` 相当)。
    @Test func unweightedChildrenKeepTheirWidthBeforeWeightsShare() {
        let slots = FlexDistribution.compute(
            ideals: [100, 500, 500], weights: [nil, 2, 1], available: 400, spacing: 0, justify: nil)
        #expect(slots.map(\.width) == [100, 200, 100])
    }

    /// weight なしの子だけで提案幅を超えるなら、そちらを比例縮小し、weight 付きの子は 0 になる。
    /// 行が提案幅からはみ出さないことが優先される。
    @Test func weightsGetNothingWhenUnweightedChildrenAlreadyOverflow() {
        let slots = FlexDistribution.compute(
            ideals: [300, 300, 400], weights: [nil, nil, 1], available: 300, spacing: 0, justify: nil)
        #expect(slots.map(\.width) == [150, 150, 0])
        #expect(slots.map(\.width).reduce(0, +) <= 300)
    }

    /// weight なしの spaceBetween(ラベル + 値): 余白が gap として子の間に入り、
    /// 最後の子が右端に到達する。
    @Test func spaceBetweenPushesApart() {
        let slots = FlexDistribution.compute(
            ideals: [100, 50], weights: [nil, nil], available: 350, spacing: 10, justify: .spaceBetween)
        #expect(slots.map(\.width) == [100, 50])
        #expect(slots[1].x + slots[1].width == 350)
    }

    /// weight なしでも合計が提案幅を超えるなら比例縮小(flex-shrink 相当)し、はみ出さない。
    @Test func overflowShrinksProportionally() {
        let slots = FlexDistribution.compute(
            ideals: [300, 300], weights: [nil, nil], available: 310, spacing: 10, justify: nil)
        #expect(slots.map(\.width) == [150, 150])
        #expect(slots[1].x + slots[1].width <= 310)
    }

    @Test func spaceEvenlyDistributesPads() {
        let slots = FlexDistribution.compute(
            ideals: [50, 50], weights: [nil, nil], available: 190, spacing: 0, justify: .spaceEvenly)
        #expect(slots.map(\.x) == [30, 110])
    }

    @Test func emptyAndSingleChild() {
        #expect(FlexDistribution.compute(
            ideals: [], weights: [], available: 100, spacing: 8, justify: .spaceBetween).isEmpty)
        let single = FlexDistribution.compute(
            ideals: [40], weights: [nil], available: 100, spacing: 8, justify: .spaceBetween)
        #expect(single == [FlexDistribution.Slot(x: 0, width: 40)])
    }
}

/// 実機 capture 79EC966D-7CF3-466A-8682-7975EC08C387 (2026-06-06, A2AResearchDemo) の
/// UpdateComponents をそのまま固定化した回帰 corpus。
/// モデルのこの応答が再来しなくても、この構造(spaceBetween Row + weighted 長文 Column)が
/// 画面幅に収まることを永続的に検証する。
@MainActor
@Suite("Weighted row overflow regression (capture 79EC966D)")
struct WeightedRowRegressionTests {
    static let canvas = CGSize(width: 375, height: 700)

    static let captureCorpus = """
    [
      {"version":"v1.0","createSurface":{"surfaceId":"s1","catalogId":"basic"}},
      {"version":"v1.0","updateComponents":{"surfaceId":"s1","components":[
        {"id":"root","component":"Column","align":"stretch","children":["comparisonHeader","comparisonContent"]},
        {"id":"comparisonHeader","component":"Text","text":"「ワークフロー」と「エージェント」の違い"},
        {"id":"comparisonContent","component":"Card","child":"comparisonGrid"},
        {"id":"comparisonGrid","component":"Column","align":"stretch","children":["compRow"]},
        {"id":"compRow","component":"Row","align":"start","justify":"spaceBetween","children":["compLeft","compRight"]},
        {"id":"compLeft","component":"Column","weight":1,"children":["compLeftTitle","compLeftDesc"]},
        {"id":"compLeftTitle","component":"Text","text":"🚅 ワークフロー"},
        {"id":"compLeftDesc","component":"Text","text":"**制御：人間（コード）**\\nあらかじめ決められた「レールの上の処理」を正確に実行します。予測可能性が高く、業務プロセスの自動化に最適です。"},
        {"id":"compRight","component":"Column","weight":1,"children":["compRightTitle","compRightDesc"]},
        {"id":"compRightTitle","component":"Text","text":"🧭 エージェント"},
        {"id":"compRightDesc","component":"Text","text":"**制御：AI（自律判断）**\\n目的を与えられ、AIが自分で「次に何をするか」を判断しながら進みます。未知の課題や柔軟な対応が必要な場面で強力です。"}
      ]}}
    ]
    """

    private func surface(_ json: String) throws -> TypedSurface<BasicCatalog> {
        var components: [StructuredValue] = []
        let dataModel = DataModel()
        for message in try JSONDecoder().decode([AgentMessage].self, from: Data(json.utf8)) {
            switch message {
            case .updateComponents(let uc): components += uc.components
            case .updateDataModel(let udm): dataModel.set(udm.path ?? "", udm.value)
            default: break
            }
        }
        let nodes = try components.map { try $0.decode(CatalogNode<BasicComponent>.self) }
        return TypedSurface(rootId: "root", nodes: nodes, dataModel: dataModel)
    }

    private func rasterize(_ view: some View) -> CGImage? {
        // 透明背景は RGB=0 で「ink」と誤判定されるため白で不透明化する
        let sized = AnyView(view.frame(
            width: Self.canvas.width, height: Self.canvas.height, alignment: .topLeading)
            .background(Color.white))
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

    /// x ∈ [from, to) の縦帯に含まれる「content」(暗い)ピクセル数。
    private func contentPixels(_ image: CGImage, from: Int = 0, to: Int? = nil) -> Int {
        let p = pixels(image)
        let w = image.width, h = image.height
        let upper = to ?? w
        var count = 0
        for y in 0..<h {
            for x in from..<upper {
                let i = (y * w + x) * 4
                if max(p[i], p[i + 1], p[i + 2]) < 160 { count += 1 }
            }
        }
        return count
    }

    private func writePNG(_ image: CGImage, _ path: String) {
        guard let dest = CGImageDestinationCreateWithURL(
            URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }

    @Test("weight はデコードされ typed node から取得できる")
    func weightRoundTrips() throws {
        let surface = try surface(Self.captureCorpus)
        guard case .known(let left) = surface.node("compLeft"),
              case .known(let right) = surface.node("compRight"),
              case .known(let row) = surface.node("compRow") else {
            Issue.record("expected known nodes")
            return
        }
        #expect(left.weight == 1)
        #expect(right.weight == 1)
        #expect(row.weight == nil)
    }

    /// 実レンダリング: weight 2 : 1 の Row で、2 列の境目が幅の 2/3 に来る。
    ///
    /// FlexDistribution の純粋テストと違い、実際の子 (Column) が自分の ideal 幅として
    /// 「提案された幅そのもの」を返す経路を通る。旧実装はこの経路で必ず 1 : 1 に潰れていた。
    static let twoToOneCorpus = """
    [
      {"version":"v1.0","createSurface":{"surfaceId":"s1","catalogId":"basic"}},
      {"version":"v1.0","updateComponents":{"surfaceId":"s1","components":[
        {"id":"root","component":"Column","align":"stretch","children":["row"]},
        {"id":"row","component":"Row","align":"start","children":["left","right"]},
        {"id":"left","component":"Column","weight":2,"align":"stretch","children":["leftText"]},
        {"id":"leftText","component":"Text","text":"AAAA AAAA AAAA AAAA AAAA AAAA AAAA AAAA AAAA AAAA AAAA AAAA"},
        {"id":"right","component":"Column","weight":1,"align":"stretch","children":["rightText"]},
        {"id":"rightText","component":"Text","text":"BBBB BBBB BBBB BBBB BBBB BBBB BBBB BBBB BBBB BBBB BBBB BBBB"}
      ]}}
    ]
    """

    /// 列と列の間の「インクが 1 ピクセルも無い縦帯」のうち最も広いものの中心 x (0...1 に正規化)。
    /// 2 列レイアウトではこれが列の境目になる。
    private func widestGapCenter(_ image: CGImage) -> Double? {
        let p = pixels(image)
        let w = image.width, h = image.height
        // 端の余白は境目ではないので探索範囲から外す。
        let lo = w / 5, hi = w * 4 / 5
        var inked = [Bool](repeating: false, count: w)
        for x in lo..<hi {
            for y in 0..<h where max(p[(y * w + x) * 4], p[(y * w + x) * 4 + 1], p[(y * w + x) * 4 + 2]) < 250 {
                inked[x] = true
                break
            }
        }
        var best: (start: Int, length: Int)? = nil
        var runStart: Int? = nil
        for x in lo...hi {
            if x < hi, !inked[x] {
                if runStart == nil { runStart = x }
            } else if let start = runStart {
                let length = x - start
                if best == nil || length > best!.length { best = (start, length) }
                runStart = nil
            }
        }
        guard let best, best.length > 2 else { return nil }
        return (Double(best.start) + Double(best.length) / 2) / Double(w)
    }

    @Test("weight 2 : 1 の Row は実レンダリングでも 2 : 1 に分かれる")
    func twoToOneSplitsAtTwoThirds() throws {
        let img = try #require(rasterize(A2UISurfaceView(try surface(Self.twoToOneCorpus))))
        writePNG(img, "/tmp/typed_two_to_one_row.png")
        let center = try #require(widestGapCenter(img), "列の境目が見つからない")
        // 2 : 1 なら ~0.667、1 : 1 なら ~0.5。両者を確実に区別する幅で挟む。
        #expect(center > 0.60, "境目 x=\(center): weight が効いていない(1:1 に潰れている)")
        #expect(center < 0.74, "境目 x=\(center)")
    }

    @Test("weighted spaceBetween Row が画面幅からはみ出さない(マージンににじまない)")
    func noHorizontalOverflow() throws {
        // ホストの余白を模した 16pt パディング。オーバーフローすればここにインクが漏れる。
        let img = try #require(rasterize(
            A2UISurfaceView(try surface(Self.captureCorpus)).padding(16)))
        writePNG(img, "/tmp/typed_weighted_row.png")

        let total = contentPixels(img)
        #expect(total > 1500, "surface が描画されていること")

        // 旧実装では中央寄せオーバーフローで本文がラスタ両端を貫通していた。
        // 正しいレイアウトでは外周 6pt(Retina スケール換算)の帯はほぼ無地になる。
        let strip = img.width * 6 / Int(Self.canvas.width)
        let leftEdge = contentPixels(img, from: 0, to: strip)
        let rightEdge = contentPixels(img, from: img.width - strip)
        #expect(leftEdge < 40, "left edge ink: \(leftEdge)")
        #expect(rightEdge < 40, "right edge ink: \(rightEdge)")
    }

    @Test("長文が折り返されて縦に伸びる(1 行貫通しない)")
    func longTextWraps() throws {
        let img = try #require(rasterize(A2UISurfaceView(try surface(Self.captureCorpus))))
        let p = pixels(img)
        let w = img.width
        // 白背景より少しでも暗ければインクとみなす。v1.0 で見出し variant が廃止され、この
        // キャプチャから濃い要素が無くなったため、`< 160` のような濃さ前提の閾値では
        // 折り返した本文を拾えない(本文は輝度 ~242 の淡色で描かれる)。
        var lowestInk = 0
        for y in 0..<img.height {
            for x in 0..<w {
                let i = (y * w + x) * 4
                if max(p[i], p[i + 1], p[i + 2]) < 245 { lowestInk = y }
            }
        }
        // 2 カラム各 ~180pt 幅に折り返されれば本文は複数行になり、コンテンツは
        // タイトル + 1 行(~120px)よりずっと下まで届く。
        #expect(lowestInk > 200, "lowest ink y: \(lowestInk)")
    }
}
