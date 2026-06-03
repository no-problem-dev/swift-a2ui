import Testing
@testable import A2UIRuntime
import A2UISurface
import A2UICore

@Suite("DataContext resolution")
struct DataContextResolutionTests {

    private func employeesModel() -> DataModel {
        DataModel(.object([
            "company": .string("Acme Corp"),
            "employees": .array([
                .object(["name": .string("Alice"), "role": .string("Engineer")]),
                .object(["name": .string("Bob"), "role": .string("Designer")]),
            ]),
        ]))
    }

    @Test("literal DynamicString resolves to itself")
    func literalString() {
        let ctx = DataContext(dataModel: DataModel())
        #expect(ctx.resolveString(.literal("Hello")) == "Hello")
    }

    @Test("binding DynamicString resolves via absolute path")
    func bindingStringAbsolute() {
        let ctx = DataContext(dataModel: employeesModel())
        #expect(ctx.resolveString(.binding(DataBinding(path: "/company"))) == "Acme Corp")
    }

    @Test("spec scope example: relative binding resolves against item scope")
    func specScopeRelative() {
        let dm = employeesModel()
        // Template iterating /employees, instantiated for item 0.
        let item0 = DataContext(dataModel: dm, path: "/employees/0")
        #expect(item0.resolveString(.binding(DataBinding(path: "name"))) == "Alice")
        // Absolute path still resolves globally from within the child scope.
        #expect(item0.resolveString(.binding(DataBinding(path: "/company"))) == "Acme Corp")

        let item1 = DataContext(dataModel: dm, path: "/employees/1")
        #expect(item1.resolveString(.binding(DataBinding(path: "name"))) == "Bob")
    }

    @Test("nested() creates a child scope for templates")
    func nestedScope() {
        let dm = employeesModel()
        let root = DataContext(dataModel: dm, path: "")
        let item1 = root.nested("/employees/1")
        #expect(item1.path == "/employees/1")
        #expect(item1.resolveString(.binding(DataBinding(path: "role"))) == "Designer")
    }

    @Test("binding to missing path coerces to empty string")
    func missingPathCoerces() {
        let ctx = DataContext(dataModel: DataModel(.object([:])))
        #expect(ctx.resolveString(.binding(DataBinding(path: "/missing"))) == "")
    }

    @Test("DynamicValue binding resolves to concrete StructuredValue")
    func dynamicValueBinding() {
        let dm = DataModel(.object(["count": .int(7)]))
        let ctx = DataContext(dataModel: dm)
        #expect(ctx.resolve(.binding(DataBinding(path: "/count"))) == .int(7))
    }

    @Test("DynamicBoolean binding coerces (string 'true' → true)")
    func dynamicBoolCoercion() {
        let dm = DataModel(.object(["flag": .string("true")]))
        let ctx = DataContext(dataModel: dm)
        #expect(ctx.resolveBool(.binding(DataBinding(path: "/flag"))) == true)
    }

    @Test("DynamicNumber binding coerces (numeric string → number)")
    func dynamicNumberCoercion() {
        let dm = DataModel(.object(["n": .string("12.5")]))
        let ctx = DataContext(dataModel: dm)
        #expect(ctx.resolveNumber(.binding(DataBinding(path: "/n"))) == 12.5)
    }
}

@Suite("DataContext subscription & two-way binding")
struct DataContextSubscriptionTests {

    @Test("subscribeString fires initial value then updates")
    func subscribeStringReactive() {
        let dm = DataModel(.object(["user": .object(["name": .string("")])]))
        let ctx = DataContext(dataModel: dm)
        var values: [String] = []
        let sub = ctx.subscribeString(.binding(DataBinding(path: "/user/name"))) { values.append($0) }
        // Simulate a TextField writing on each keystroke.
        ctx.set("/user/name", .string("J"))
        ctx.set("/user/name", .string("Jane"))
        #expect(values == ["", "J", "Jane"])
        sub.cancel()
    }

    @Test("literal subscription fires once and is inert")
    func literalSubscriptionOnce() {
        let dm = DataModel()
        let ctx = DataContext(dataModel: dm)
        var values: [String] = []
        let sub = ctx.subscribeString(.literal("Static")) { values.append($0) }
        #expect(values == ["Static"])
        sub.cancel()
    }

    @Test("write via scoped context uses relative resolution")
    func scopedWrite() {
        let dm = DataModel(.object(["items": .array([.object(["done": .bool(false)])])]))
        let item0 = DataContext(dataModel: dm, path: "/items/0")
        item0.set("done", .bool(true))   // relative write
        #expect(dm.get("/items/0/done") == .bool(true))
    }
}

