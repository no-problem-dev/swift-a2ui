import Foundation

/// The renderer's own user-facing text — everything on screen that the agent did not write.
///
/// A package published for other people cannot decide what language its consumers ship in. These
/// used to be Japanese literals, so an English-locale host rendered Japanese onto its users'
/// screens with no way to change it. They resolve against this package's bundle now, which ships
/// English as the source language and Japanese as a translation, and the host's locale picks.
///
/// `bundle` is injectable because a locale's table is chosen by the bundle, not by a `Locale`
/// value — which is what lets a test ask what a given language actually ships, instead of
/// asserting against whichever machine the suite happens to run on.
enum RendererStrings {

    /// Shown before an agent's root component arrives, so a surface being streamed in is not blank.
    static func generatingUI(_ bundle: Bundle = .module) -> String {
        String(localized: "surface.generating", defaultValue: "Generating UI…", bundle: bundle,
               comment: "Placeholder shown while a surface is still being generated")
    }

    /// The progress pill floated over a surface while the agent is still working on it.
    static func busy(_ bundle: Bundle = .module) -> String {
        String(localized: "surface.busy", defaultValue: "Working", bundle: bundle,
               comment: "Label on the progress pill shown over a busy surface")
    }

    /// Stands in for a video or audio tile whose URL is empty, so the tile is not a bare icon.
    static func untitledMedia(_ bundle: Bundle = .module) -> String {
        String(localized: "media.untitled", defaultValue: "Media", bundle: bundle,
               comment: "Fallback label for a media tile with no URL")
    }

    /// The package's table for one language, for tests that assert a specific translation ships.
    static func bundle(forLanguage code: String) -> Bundle? {
        Bundle.module.path(forResource: code, ofType: "lproj").flatMap(Bundle.init(path:))
    }
}
