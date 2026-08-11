import SwiftUI

extension EnvironmentValues {
    /// Whether tapping an `Image`, `Video`, or `AudioPlayer` opens the in-app media viewer.
    /// Enabled by default.
    ///
    /// Turn it off with `a2uiMediaViewer(false)` when the host already has its own preview route,
    /// or when the surface is embedded somewhere a `fullScreenCover` is unacceptable. This is
    /// purely client-side behavior: the a2ui catalog schema says nothing about it.
    @Entry public var a2uiMediaViewerEnabled: Bool = true
}

extension View {
    /// Controls whether the A2UI renderer opens its media viewer on tap, for this subtree.
    ///
    /// ```swift
    /// A2UISurfaceView(surface)
    ///     .a2uiMediaViewer(false) // tapping media no longer opens the viewer
    /// ```
    public func a2uiMediaViewer(_ enabled: Bool) -> some View {
        environment(\.a2uiMediaViewerEnabled, enabled)
    }
}
