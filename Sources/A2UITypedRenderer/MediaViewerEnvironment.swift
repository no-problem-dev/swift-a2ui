import SwiftUI

extension EnvironmentValues {
    /// `Image` / `Video` / `AudioPlayer` コンポーネントのタップで
    /// アプリ内メディアビューアを起動するか（デフォルト有効）。
    ///
    /// ホストが独自のプレビュー導線を持つ場合や、fullScreenCover を
    /// 許容できない埋め込み文脈では `a2uiMediaViewer(false)` で無効化できる。
    /// スキーマ（公式 a2ui カタログ）には一切関与しないクライアント側 UX。
    @Entry public var a2uiMediaViewerEnabled: Bool = true
}

extension View {
    /// A2UI レンダラのメディアビューア起動を制御する
    ///
    /// ```swift
    /// A2UISurfaceView(surface)
    ///     .a2uiMediaViewer(false) // タップでのビューア起動を無効化
    /// ```
    public func a2uiMediaViewer(_ enabled: Bool) -> some View {
        environment(\.a2uiMediaViewerEnabled, enabled)
    }
}
