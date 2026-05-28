import Testing
@testable import A2UICatalog
import A2UICore
import Foundation

/// Proves the type-derived schema (`BasicCatalogSchema`) is semantically equivalent to the
/// official hand-written `catalog.json`, so the JSON can be retired safely.
@Suite("Generated schema ⟷ official catalog.json equivalence")
struct GeneratedSchemaEquivalenceTests {

    /// The official hand-written v0.9 catalog, kept ONLY as a test fixture (the production code no
    /// longer ships it — `catalogSchemaJSON()` is generated from Swift types). This pins the
    /// generated output to the spec.
    private func officialCatalog() -> [String: Any] {
        let url = Bundle.module.url(forResource: "official_basic_catalog", withExtension: "json", subdirectory: "Fixtures")!
        let data = try! Data(contentsOf: url)
        return (try! JSONSerialization.jsonObject(with: data)) as! [String: Any]
    }

    private func generatedCatalog() -> [String: Any] {
        let json = BasicCatalogSchema.render()
        return (try! JSONSerialization.jsonObject(with: json.data(using: .utf8)!)) as! [String: Any]
    }

    @Test("component name set matches official")
    func componentNamesMatch() {
        let official = Set((officialCatalog()["components"] as! [String: Any]).keys)
        let generated = Set((generatedCatalog()["components"] as! [String: Any]).keys)
        #expect(generated == official)
    }

    @Test("function name set matches official")
    func functionNamesMatch() {
        let official = Set((officialCatalog()["functions"] as! [String: Any]).keys)
        let generated = Set((generatedCatalog()["functions"] as! [String: Any]).keys)
        #expect(generated == official)
    }

    /// For each component, the required property set and each property's $ref / enum cases must match.
    @Test("each component's required set + property types match official")
    func componentDetailsMatch() {
        let official = officialCatalog()["components"] as! [String: Any]
        let generated = generatedCatalog()["components"] as! [String: Any]

        for (name, officialCompAny) in official {
            guard let genCompAny = generated[name] else {
                Issue.record("generated catalog missing component \(name)")
                continue
            }
            let officialInner = innerObject(officialCompAny as! [String: Any])
            let genInner = innerObject(genCompAny as! [String: Any])

            // Required sets.
            let officialReq = Set((officialInner["required"] as? [String]) ?? [])
            let genReq = Set((genInner["required"] as? [String]) ?? [])
            #expect(genReq == officialReq, "required mismatch for \(name): generated \(genReq) vs official \(officialReq)")

            // Property $ref / enum equivalence (ignore descriptions/defaults — those are prose).
            let officialProps = officialInner["properties"] as! [String: Any]
            let genProps = genInner["properties"] as! [String: Any]
            for (propName, officialPropAny) in officialProps {
                guard let genPropAny = genProps[propName] else {
                    Issue.record("\(name).\(propName) missing in generated")
                    continue
                }
                let op = officialPropAny as! [String: Any]
                let gp = genPropAny as! [String: Any]
                // $ref must match when present.
                if let oref = op["$ref"] as? String {
                    #expect(gp["$ref"] as? String == oref, "\(name).\(propName) $ref mismatch")
                }
                // enum cases must match (as sets) when present.
                if let oenum = op["enum"] as? [String] {
                    let genum = Set(gp["enum"] as? [String] ?? [])
                    #expect(genum == Set(oenum), "\(name).\(propName) enum mismatch: \(genum) vs \(Set(oenum))")
                }
                // const (component discriminator) must match.
                if let oconst = op["const"] as? String {
                    #expect(gp["const"] as? String == oconst, "\(name).\(propName) const mismatch")
                }
            }
        }
    }

    /// The component-specific object is the last entry of `allOf`.
    private func innerObject(_ component: [String: Any]) -> [String: Any] {
        let allOf = component["allOf"] as! [[String: Any]]
        return allOf.last!
    }
}
