import SwiftUI
import A2UICatalog

/// flex 配分の純粋計算。サイズ決定は weight(flex-grow)が司り、justify は余白の配置だけを司る
/// (CSS flexbox と同じ意味論)。合計が提案幅を超える場合は比例縮小(flex-shrink 相当)するため、
/// 子がどれだけ長文でも Row が提案幅を超えてサーフェス全体を押し広げることはない。
/// UI 非依存で、単体でテストする。
enum FlexDistribution {
    struct Slot: Equatable {
        var x: CGFloat
        var width: CGFloat
    }

    static func compute(
        ideals: [CGFloat],
        weights: [Double?],
        available: CGFloat,
        spacing: CGFloat,
        justify: LayoutJustify?
    ) -> [Slot] {
        let count = ideals.count
        guard count > 0 else { return [] }
        let content = max(0, available - spacing * CGFloat(count - 1))

        var widths = ideals.map { min(max($0, 0), content) }
        let total = widths.reduce(0, +)
        if total > content, total > 0 {
            let factor = content / total
            widths = widths.map { $0 * factor }
        }

        var leftover = content - widths.reduce(0, +)
        let totalWeight = weights.compactMap { $0 }.filter { $0 > 0 }.reduce(0, +)
        if totalWeight > 0, leftover > 0 {
            for index in widths.indices {
                if let weight = weights[index], weight > 0 {
                    widths[index] += leftover * CGFloat(weight / totalWeight)
                }
            }
            leftover = 0
        }

        var lead: CGFloat = 0
        var gap = spacing
        switch justify {
        case .center:
            lead = leftover / 2
        case .end:
            lead = leftover
        case .spaceBetween where count > 1:
            gap += leftover / CGFloat(count - 1)
        case .spaceAround:
            let pad = leftover / CGFloat(count)
            lead = pad / 2
            gap += pad
        case .spaceEvenly:
            let pad = leftover / CGFloat(count + 1)
            lead = pad
            gap += pad
        case .stretch:
            let extra = leftover / CGFloat(count)
            widths = widths.map { $0 + extra }
        default:
            break
        }

        var x = lead
        var slots: [Slot] = []
        for width in widths {
            slots.append(Slot(x: x, width: width))
            x += width + gap
        }
        return slots
    }
}

/// 子の weight を Layout へ運ぶ。nil = weight 宣言なし(intrinsic 幅)。
enum FlexWeightKey: LayoutValueKey {
    static let defaultValue: Double? = nil
}

/// `Row` の本実装。子の ideal 幅は「提案幅を上限に」計測するため、長文 Text は折り返しで応える。
struct FlexRowLayout: Layout {
    let justify: LayoutJustify?
    let align: LayoutAlign?
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        guard let width = proposal.width else {
            let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
            let total = sizes.reduce(0) { $0 + $1.width } + spacing * CGFloat(subviews.count - 1)
            return CGSize(width: total, height: sizes.map(\.height).max() ?? 0)
        }
        let slots = slots(available: width, subviews: subviews)
        let height = zip(subviews, slots).map { subview, slot in
            subview.sizeThatFits(ProposedViewSize(width: slot.width, height: proposal.height)).height
        }.max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let slots = slots(available: bounds.width, subviews: subviews)
        for (subview, slot) in zip(subviews, slots) {
            let proposed = ProposedViewSize(
                width: slot.width, height: align == .stretch ? bounds.height : nil)
            let size = subview.sizeThatFits(proposed)
            let y = switch align {
            case .center: bounds.midY - size.height / 2
            case .end: bounds.maxY - size.height
            default: bounds.minY
            }
            subview.place(at: CGPoint(x: bounds.minX + slot.x, y: y), proposal: proposed)
        }
    }

    private func slots(available: CGFloat, subviews: Subviews) -> [FlexDistribution.Slot] {
        FlexDistribution.compute(
            ideals: subviews.map { $0.sizeThatFits(ProposedViewSize(width: available, height: nil)).width },
            weights: subviews.map { $0[FlexWeightKey.self] },
            available: available,
            spacing: spacing,
            justify: justify
        )
    }
}
