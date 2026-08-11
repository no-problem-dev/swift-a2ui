import SwiftUI
import A2UICatalog

/// Pure arithmetic for flex distribution: `weight` (flex-grow) decides size, `justify` only places
/// the leftover space — the same split of duties as CSS flexbox.
///
/// When the children's ideal widths add up to more than the proposal, they are scaled down
/// proportionally (the flex-shrink equivalent), so no amount of long text in a child can push the
/// row past its proposed width and stretch the whole surface. Free of UIKit/SwiftUI so it can be
/// tested on its own.
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

/// Carries a child's weight through to the layout. `nil` means the child declared no weight and
/// keeps its intrinsic width.
enum FlexWeightKey: LayoutValueKey {
    static let defaultValue: Double? = nil
}

/// The real implementation behind `Row`.
///
/// Each child's ideal width is measured against the row's own proposed width as the ceiling, so a
/// long `Text` answers with a wrapped height rather than a single very wide line.
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
