import SwiftUI
import A2UICatalog

// Faithful port of A2UIRenderer/Support/Mappings.swift — the alignment/justify mappings the
// existing RowView/ColumnView/ListView rely on. Kept byte-identical so layout matches exactly.

extension Optional where Wrapped == LayoutAlign {
    var horizontal: HorizontalAlignment {
        switch self {
        case .center: .center
        case .end: .trailing
        default: .leading
        }
    }
    var vertical: VerticalAlignment {
        switch self {
        case .center, .stretch: .center
        case .end: .bottom
        default: .top
        }
    }
    var frameAlignment: Alignment {
        switch self {
        case .center: .center
        case .end: .trailing
        default: .leading
        }
    }
}

extension Optional where Wrapped == LayoutJustify {
    var leadingSpacer: Bool { self == .center || self == .end }
    var trailingSpacer: Bool { self == .center || self == .start || self == nil }
}
