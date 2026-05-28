import Testing
@testable import A2UIRuntime
import A2UISurface
import A2UICore

@Suite("TemplateExpander")
struct TemplateExpanderTests {

    private func employeesContext() -> DataContext {
        let dm = DataModel(.object([
            "company": .string("Acme Corp"),
            "employees": .array([
                .object(["name": .string("Alice")]),
                .object(["name": .string("Bob")]),
                .object(["name": .string("Carol")]),
            ]),
        ]))
        return DataContext(dataModel: dm, functions: BasicFunctions())
    }

    @Test("static ids keep the parent scope")
    func staticIds() {
        let ctx = DataContext(dataModel: DataModel(), path: "/scope")
        let result = TemplateExpander.expand(.ids(["a", "b"]), in: ctx)
        #expect(result == [
            ResolvedChild(componentId: "a", basePath: "/scope"),
            ResolvedChild(componentId: "b", basePath: "/scope"),
        ])
    }

    @Test("template over array yields one child per element with indexed scope")
    func templateArray() {
        let ctx = employeesContext()
        let result = TemplateExpander.expand(.template(componentId: "card", path: "/employees"), in: ctx)
        #expect(result == [
            ResolvedChild(componentId: "card", basePath: "/employees/0"),
            ResolvedChild(componentId: "card", basePath: "/employees/1"),
            ResolvedChild(componentId: "card", basePath: "/employees/2"),
        ])
    }

    @Test("template instance scope makes relative bindings resolve to the element (spec scope)")
    func templateScopeResolution() {
        let ctx = employeesContext()
        let children = TemplateExpander.expand(.template(componentId: "card", path: "/employees"), in: ctx)
        // For each instance, a relative binding "name" must resolve to that element's name.
        let names = children.map { child -> String in
            let itemCtx = ctx.nested(child.basePath)
            return itemCtx.resolveString(.binding(DataBinding(path: "name")))
        }
        #expect(names == ["Alice", "Bob", "Carol"])
    }

    @Test("template instance can still reach root scope via absolute path")
    func templateAbsoluteFromInstance() {
        let ctx = employeesContext()
        let children = TemplateExpander.expand(.template(componentId: "card", path: "/employees"), in: ctx)
        let itemCtx = ctx.nested(children[1].basePath)  // /employees/1
        #expect(itemCtx.resolveString(.binding(DataBinding(path: "/company"))) == "Acme Corp")
    }

    @Test("empty array yields no children (graceful)")
    func emptyArray() {
        let dm = DataModel(.object(["items": .array([])]))
        let ctx = DataContext(dataModel: dm)
        #expect(TemplateExpander.expand(.template(componentId: "row", path: "/items"), in: ctx).isEmpty)
    }

    @Test("missing path yields no children (progressive rendering)")
    func missingPath() {
        let ctx = DataContext(dataModel: DataModel(.object([:])))
        #expect(TemplateExpander.expand(.template(componentId: "row", path: "/notyet"), in: ctx).isEmpty)
    }

    @Test("template over object iterates keys in sorted order")
    func templateObject() {
        let dm = DataModel(.object(["map": .object(["b": .int(2), "a": .int(1)])]))
        let ctx = DataContext(dataModel: dm)
        let result = TemplateExpander.expand(.template(componentId: "row", path: "/map"), in: ctx)
        #expect(result == [
            ResolvedChild(componentId: "row", basePath: "/map/a"),
            ResolvedChild(componentId: "row", basePath: "/map/b"),
        ])
    }

    @Test("nested template scope: relative path resolves against parent scope")
    func nestedTemplateScope() {
        // departments[0].members → relative "members" resolved within /departments/0.
        let dm = DataModel(.object([
            "departments": .array([
                .object(["members": .array([.object(["n": .string("x")]), .object(["n": .string("y")])])]),
            ]),
        ]))
        let deptCtx = DataContext(dataModel: dm, path: "/departments/0")
        let result = TemplateExpander.expand(.template(componentId: "m", path: "members"), in: deptCtx)
        #expect(result == [
            ResolvedChild(componentId: "m", basePath: "/departments/0/members/0"),
            ResolvedChild(componentId: "m", basePath: "/departments/0/members/1"),
        ])
    }

    @Test("expandRaw decodes a raw children property")
    func expandRaw() {
        let ctx = employeesContext()
        let raw: AnyCodable = .object(["componentId": .string("card"), "path": .string("/employees")])
        let result = TemplateExpander.expandRaw(raw, in: ctx)
        #expect(result?.count == 3)
        #expect(result?.first == ResolvedChild(componentId: "card", basePath: "/employees/0"))
    }
}
