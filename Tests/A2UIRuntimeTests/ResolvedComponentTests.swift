import Testing
@testable import A2UIRuntime
import A2UISurface
import A2UICore

@MainActor
@Suite("ResolvedComponent: data props")
struct ResolvedComponentDataPropsTests {

    private func make(
        _ properties: [String: StructuredValue],
        data: StructuredValue = .object([:]),
        scope: String = ""
    ) -> (ResolvedComponent, DataModel) {
        let dm = DataModel(data)
        let fns = BasicFunctions()
        let ctx = ComponentContext(
            componentId: "c",
            componentType: "Text",
            properties: properties,
            dataContext: DataContext(dataModel: dm, path: scope, functions: fns)
        )
        return (ResolvedComponent(context: ctx, functions: fns), dm)
    }

    @Test("literal prop passes through")
    func literalProp() {
        let (rc, _) = make(["text": .string("Hello")])
        #expect(rc.props["text"] == .string("Hello"))
    }

    @Test("bound prop resolves initial value")
    func boundInitial() {
        let (rc, _) = make(["text": .object(["path": .string("/title")])], data: .object(["title": .string("Welcome")]))
        #expect(rc.props["text"] == .string("Welcome"))
    }

    @Test("bound prop updates reactively when data changes")
    func boundReactive() {
        let (rc, dm) = make(["text": .object(["path": .string("/title")])], data: .object(["title": .string("A")]))
        #expect(rc.props["text"] == .string("A"))
        dm.set("/title", .string("B"))
        #expect(rc.props["text"] == .string("B"))
    }

    @Test("relative bound prop resolves against scope")
    func relativeScoped() {
        let (rc, _) = make(
            ["text": .object(["path": .string("name")])],
            data: .object(["items": .array([.object(["name": .string("Alice")])])]),
            scope: "/items/0"
        )
        #expect(rc.props["text"] == .string("Alice"))
    }

    @Test("scope exposes the node's data scope")
    func exposesScope() {
        let (rc, _) = make(["text": .literalString("x")], scope: "/items/3")
        #expect(rc.scope == "/items/3")
    }

    @Test("bindingPath returns the raw path for a binding, nil for a literal")
    func bindingPathExtraction() {
        let (rc, _) = make([
            "value": .object(["path": .string("/form/email")]),
            "label": .string("Email"),
        ])
        #expect(rc.bindingPath("value") == "/form/email")
        #expect(rc.bindingPath("label") == nil)
    }

    @Test("write(_:_:) writes back through the binding path (View → Model)")
    func writeBack() {
        let (rc, dm) = make(["value": .object(["path": .string("/form/email")])], data: .object([:]))
        rc.write("value", .string("jane@example.com"))
        #expect(dm.get("/form/email") == .string("jane@example.com"))
    }

    @Test("write respects scope for relative binding (template input)")
    func writeScoped() {
        let (rc, dm) = make(
            ["value": .object(["path": .string("done")])],
            data: .object(["items": .array([.object(["done": .bool(false)])])]),
            scope: "/items/0"
        )
        rc.write("value", .bool(true))
        #expect(dm.get("/items/0/done") == .bool(true))
    }

    @Test("write is a no-op for a literal prop")
    func writeLiteralNoOp() {
        let (rc, dm) = make(["value": .string("static")], data: .object(["x": .int(1)]))
        rc.write("value", .string("changed"))
        #expect(dm.get("/value") == nil)  // nothing written
    }
}

private extension StructuredValue {
    static func literalString(_ s: String) -> StructuredValue { .string(s) }
}

@MainActor
@Suite("ResolvedComponent: numeric accessors")
struct ResolvedComponentNumericTests {

    private func make(_ properties: [String: StructuredValue]) -> ResolvedComponent {
        let ctx = ComponentContext(
            componentId: "c", componentType: "Custom",
            properties: properties,
            dataContext: DataContext(dataModel: DataModel(), functions: BasicFunctions())
        )
        return ResolvedComponent(context: ctx, functions: BasicFunctions())
    }

    @Test("int coerces int / int-valued double / numeric string")
    func intCoercion() {
        #expect(make(["v": .int(42)]).int("v") == 42)
        #expect(make(["v": .double(7.0)]).int("v") == 7)
        #expect(make(["v": .string("18000000000000000")]).int("v") == 18000000000000000)
    }

    @Test("int rejects non-integral / out-of-range doubles")
    func intRejectsLossy() {
        #expect(make(["v": .double(3.5)]).int("v") == nil)
    }

    @Test("int returns nil for missing / non-numeric")
    func intMissing() {
        #expect(make([:]).int("v") == nil)
        #expect(make(["v": .bool(true)]).int("v") == nil)
    }

    @Test("intArray coerces each element independently")
    func intArrayCoercion() {
        let r = make(["ids": .array([.string("1"), .int(2), .double(3.0), .string("x")])])
        // String "x" is dropped (compactMap), others coerce.
        #expect(r.intArray("ids") == [1, 2, 3])
    }

    @Test("intArray returns empty for missing / non-array")
    func intArrayEmpty() {
        #expect(make([:]).intArray("ids") == [])
        #expect(make(["ids": .string("not-an-array")]).intArray("ids") == [])
    }
}

@MainActor
@Suite("ResolvedComponent: two-way binding & reactive logic (spec §8)")
struct ResolvedComponentReactivityTests {

    @Test("Two-Way Binding: field write updates a label bound to the same path")
    func twoWayBinding() {
        let dm = DataModel(.object(["user": .object(["name": .string("")])]))
        let fns = BasicFunctions()
        // A "label" component bound to /user/name.
        let labelCtx = ComponentContext(
            componentId: "label", componentType: "Text",
            properties: ["text": .object(["path": .string("/user/name")])],
            dataContext: DataContext(dataModel: dm, functions: fns)
        )
        let label = ResolvedComponent(context: labelCtx, functions: fns)
        #expect(label.props["text"] == .string(""))

        // Simulate the TextField writing the model (two-way binding write side).
        let fieldCtx = DataContext(dataModel: dm, functions: fns)
        fieldCtx.set("/user/name", .string("Jane"))

        // The label must reflect the new value (read side / reactivity).
        #expect(label.props["text"] == .string("Jane"))
        label.dispose()
    }

    @Test("Reactive Logic: checks re-evaluate when bound data changes (Button disable)")
    func reactiveChecks() {
        let dm = DataModel(.object(["email": .string("")]))
        let fns = BasicFunctions()
        let buttonCtx = ComponentContext(
            componentId: "submit", componentType: "Button",
            properties: [
                "checks": .array([
                    .object([
                        "condition": .object([
                            "call": .string("required"),
                            "args": .object(["value": .object(["path": .string("/email")])]),
                        ]),
                        "message": .string("Email is required."),
                    ]),
                ]),
            ],
            dataContext: DataContext(dataModel: dm, functions: fns)
        )
        let button = ResolvedComponent(context: buttonCtx, functions: fns)
        // Initially invalid → message present (Button should be disabled).
        #expect(button.validationMessage == "Email is required.")
        // User fills email → check passes → message clears reactively.
        dm.set("/email", .string("a@b.com"))
        #expect(button.validationMessage == nil)
        button.dispose()
    }
}

@MainActor
@Suite("ResolvedComponent: structural children")
struct ResolvedComponentStructuralTests {

    private func make(_ properties: [String: StructuredValue], data: StructuredValue = .object([:])) -> ResolvedComponent {
        let ctx = ComponentContext(
            componentId: "c", componentType: "Column",
            properties: properties,
            dataContext: DataContext(dataModel: DataModel(data), functions: BasicFunctions())
        )
        return ResolvedComponent(context: ctx, functions: BasicFunctions())
    }

    @Test("single child field")
    func singleChild() {
        let rc = make(["child": .string("inner")])
        #expect(rc.children == [ResolvedChild(componentId: "inner", basePath: "")])
        // child must NOT leak into data props
        #expect(rc.props["child"] == nil)
    }

    @Test("static children list")
    func staticChildren() {
        let rc = make(["children": .array([.string("a"), .string("b")])])
        #expect(rc.children == [
            ResolvedChild(componentId: "a", basePath: ""),
            ResolvedChild(componentId: "b", basePath: ""),
        ])
    }

    @Test("template children expand with indexed scope")
    func templateChildren() {
        let rc = make(
            ["children": .object(["componentId": .string("row"), "path": .string("/items")])],
            data: .object(["items": .array([.int(1), .int(2)])])
        )
        #expect(rc.children == [
            ResolvedChild(componentId: "row", basePath: "/items/0"),
            ResolvedChild(componentId: "row", basePath: "/items/1"),
        ])
    }

    @Test("modal trigger + content")
    func modalChildren() {
        let rc = make(["trigger": .string("btn"), "content": .string("body")])
        let ids = Set(rc.children.map { $0.componentId })
        #expect(ids == ["btn", "body"])
    }

    @Test("tabs children")
    func tabsChildren() {
        let rc = make(["tabs": .array([
            .object(["title": .string("One"), "child": .string("t1")]),
            .object(["title": .string("Two"), "child": .string("t2")]),
        ])])
        let ids = Set(rc.children.map { $0.componentId })
        #expect(ids == ["t1", "t2"])
    }
}

@MainActor
@Suite("ResolvedComponent: dispatch & dispose")
struct ResolvedComponentLifecycleTests {

    @Test("dispatch forwards to the component context")
    func dispatch() {
        final class Box: @unchecked Sendable { var name: String? }
        let box = Box()
        let ctx = ComponentContext(
            componentId: "btn", componentType: "Button", properties: [:],
            dataContext: DataContext(dataModel: DataModel()),
            dispatch: { name, _ in box.name = name }
        )
        let rc = ResolvedComponent(context: ctx)
        rc.dispatch(name: "go", context: [:])
        #expect(box.name == "go")
    }

    @Test("dispose stops reactive updates")
    func disposeStops() {
        let dm = DataModel(.object(["t": .string("A")]))
        let fns = BasicFunctions()
        let ctx = ComponentContext(
            componentId: "c", componentType: "Text",
            properties: ["text": .object(["path": .string("/t")])],
            dataContext: DataContext(dataModel: dm, functions: fns)
        )
        let rc = ResolvedComponent(context: ctx, functions: fns)
        #expect(rc.props["text"] == .string("A"))
        rc.dispose()
        dm.set("/t", .string("B"))
        // After dispose, no further updates.
        #expect(rc.props["text"] == .string("A"))
    }
}
