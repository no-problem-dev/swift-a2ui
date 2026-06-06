import Testing
@testable import A2UICatalog
import A2UICore
import Foundation

/// Guarantees the **type-derived** catalog (`BasicCatalogSchema.render()`) reproduces the official
/// `catalog.json` — every description, default, type, `$ref`, and structural `$defs` — so the prompt
/// we ship to the LLM carries the exact same guardrails as Google's. Any drift fails here.
///
/// Equality is **deep and order-sensitive for arrays**: object keys are order-independent (the prompt
/// sorts them via `sortKeys` minify), but array order (`enum`, `required`, `oneOf`) is preserved into
/// the prompt and therefore pinned exactly — including the official's deliberate per-component
/// ordering (e.g. `Row.justify` alphabetical vs `Column.justify` logical), which we reproduce by
/// giving those properties an explicit order while sharing the underlying value enum.
@Suite("Generated catalog ⟷ official catalog.json FULL fidelity")
struct GeneratedCatalogFidelityTests {

    private func official() -> Any {
        let url = Bundle.module.url(forResource: "official_basic_catalog", withExtension: "json", subdirectory: "Fixtures")!
        return try! JSONSerialization.jsonObject(with: Data(contentsOf: url))
    }
    private func generated() -> Any {
        try! JSONSerialization.jsonObject(with: BasicCatalogSchema.render().data(using: .utf8)!)
    }

    @Test("generated catalog is deep-equal to official catalog.json")
    func deepEqual() {
        var diffs: [String] = []
        deepDiff(path: "$", official(), generated(), into: &diffs)
        for d in diffs.prefix(150) { Issue.record("\(d)") }
        #expect(diffs.isEmpty, "\(diffs.count) divergences from official catalog.json")
    }

    // MARK: - Recursive deep diff (official = expected, generated = actual)

    private func deepDiff(path: String, _ exp: Any, _ act: Any, into diffs: inout [String]) {
        switch (exp, act) {
        case let (e as [String: Any], a as [String: Any]):
            let ek = Set(e.keys), ak = Set(a.keys)
            for k in ek.subtracting(ak).sorted() { diffs.append("MISSING  \(path).\(k)") }
            for k in ak.subtracting(ek).sorted() { diffs.append("EXTRA    \(path).\(k)") }
            for k in ek.intersection(ak).sorted() { deepDiff(path: "\(path).\(k)", e[k]!, a[k]!, into: &diffs) }
        case let (e as [Any], a as [Any]):
            if e.count != a.count {
                diffs.append("ARRLEN   \(path): official=\(e.count) generated=\(a.count)")
            }
            // Order-sensitive: array order flows verbatim into the prompt.
            for i in 0..<min(e.count, a.count) { deepDiff(path: "\(path)[\(i)]", e[i], a[i], into: &diffs) }
        default:
            let es = String(describing: exp), gs = String(describing: act)
            if es != gs {
                diffs.append("VALUE    \(path): official=\(trunc(es)) | generated=\(trunc(gs))")
            }
        }
    }

    private func trunc(_ s: String) -> String { s.count > 80 ? String(s.prefix(80)) + "…" : s }
}
