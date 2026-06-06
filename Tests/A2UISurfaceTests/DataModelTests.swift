import Testing
@testable import A2UISurface
import A2UICore

// MARK: - JSONPointer: relative paths & auto-vivification (A2UI v0.10 extensions)

@Suite("JSONPointer relative & auto-vivification")
struct JSONPointerExtensionsTests {

    // MARK: absolutePath

    @Test("absolute path ignores scope")
    func absoluteIgnoresScope() {
        #expect(JSONPointer.absolutePath("/company", scope: "/employees/0") == "/company")
    }

    @Test("relative path resolves against scope")
    func relativeResolvesAgainstScope() {
        #expect(JSONPointer.absolutePath("name", scope: "/employees/0") == "/employees/0/name")
    }

    @Test("relative path against root scope")
    func relativeAgainstRoot() {
        #expect(JSONPointer.absolutePath("name", scope: "") == "/name")
    }

    // MARK: spec §scope-resolution example

    @Test("spec example: relative 'name' in /employees/0 scope resolves to employee name")
    func specScopeExample() {
        let data: StructuredValue = .object([
            "company": .string("Acme Corp"),
            "employees": .array([
                .object(["name": .string("Alice"), "role": .string("Engineer")]),
                .object(["name": .string("Bob"), "role": .string("Designer")]),
            ]),
        ])
        // Inside template iterating /employees, item 0: relative "name" → /employees/0/name
        #expect(JSONPointer.resolve(path: "name", scope: "/employees/0", in: data) == .string("Alice"))
        // item 1
        #expect(JSONPointer.resolve(path: "name", scope: "/employees/1", in: data) == .string("Bob"))
        // absolute "/company" resolves globally regardless of scope
        #expect(JSONPointer.resolve(path: "/company", scope: "/employees/1", in: data) == .string("Acme Corp"))
    }

    // MARK: numeric auto-vivification (next-segment numeric → Array)

    @Test("auto-viv: numeric segment creates Array")
    func autoVivNumericCreatesArray() {
        var data: StructuredValue = .object([:])
        JSONPointer.set(path: "/items/0", value: .string("a"), in: &data)
        // /items must be an Array, not an Object keyed by "0"
        #expect(JSONPointer.resolve(path: "/items", in: data) == .array([.string("a")]))
    }

    @Test("auto-viv: non-numeric segment creates Object")
    func autoVivStringCreatesObject() {
        var data: StructuredValue = .object([:])
        JSONPointer.set(path: "/user/name", value: .string("Alice"), in: &data)
        #expect(JSONPointer.resolve(path: "/user", in: data) == .object(["name": .string("Alice")]))
    }

    @Test("auto-viv: deep mixed path /a/b/0/c")
    func autoVivDeepMixed() {
        var data: StructuredValue = .object([:])
        JSONPointer.set(path: "/a/b/0/c", value: .string("deep"), in: &data)
        #expect(JSONPointer.resolve(path: "/a/b/0/c", in: data) == .string("deep"))
        // /a/b must be an Array whose element 0 is an Object
        #expect(JSONPointer.resolve(path: "/a/b/0", in: data) == .object(["c": .string("deep")]))
    }

    @Test("auto-viv: growing an array pads with sparse nulls")
    func autoVivGrowArrayPadsNulls() {
        var data: StructuredValue = .object([:])
        JSONPointer.set(path: "/list/2", value: .string("third"), in: &data)
        #expect(JSONPointer.resolve(path: "/list", in: data) == .array([.null, .null, .string("third")]))
    }
}

// MARK: - TypeCoercion (spec §3 Type Coercion Standards)

@Suite("TypeCoercion")
struct TypeCoercionTests {

    @Test("to String: null/undefined → empty")
    func stringNull() {
        #expect(TypeCoercion.toString(nil) == "")
        #expect(TypeCoercion.toString(.null) == "")
    }

    @Test("to String: numbers and booleans")
    func stringNumbersBooleans() {
        #expect(TypeCoercion.toString(.int(42)) == "42")
        #expect(TypeCoercion.toString(.double(3.5)) == "3.5")
        #expect(TypeCoercion.toString(.double(4.0)) == "4")
        #expect(TypeCoercion.toString(.bool(true)) == "true")
        #expect(TypeCoercion.toString(.bool(false)) == "false")
    }

    @Test("to String: objects/arrays are JSON-stringified")
    func stringContainers() {
        #expect(TypeCoercion.toString(.array([.int(1), .int(2)])) == "[1,2]")
        #expect(TypeCoercion.toString(.object(["a": .int(1)])) == "{\"a\":1}")
    }

    @Test("to Bool: string true/false case-insensitive, else false")
    func boolStrings() {
        #expect(TypeCoercion.toBool(.string("true")) == true)
        #expect(TypeCoercion.toBool(.string("TRUE")) == true)
        #expect(TypeCoercion.toBool(.string("false")) == false)
        #expect(TypeCoercion.toBool(.string("yes")) == false)
    }

    @Test("to Bool: numbers (0 false, non-zero true)")
    func boolNumbers() {
        #expect(TypeCoercion.toBool(.int(0)) == false)
        #expect(TypeCoercion.toBool(.int(5)) == true)
        #expect(TypeCoercion.toBool(.double(0)) == false)
        #expect(TypeCoercion.toBool(.double(0.1)) == true)
    }

    @Test("to Bool: null/undefined → false")
    func boolNull() {
        #expect(TypeCoercion.toBool(nil) == false)
        #expect(TypeCoercion.toBool(.null) == false)
    }

    @Test("to Number: null/undefined → 0, numeric strings parsed else 0")
    func numberCoercion() {
        #expect(TypeCoercion.toNumber(nil) == 0)
        #expect(TypeCoercion.toNumber(.null) == 0)
        #expect(TypeCoercion.toNumber(.string("12.5")) == 12.5)
        #expect(TypeCoercion.toNumber(.string("abc")) == 0)
        #expect(TypeCoercion.toNumber(.int(7)) == 7)
    }
}

// MARK: - DataModel (reactive get/set/subscribe, bubble & cascade)

@Suite("DataModel")
struct DataModelTests {

    @Test("get/set round trip with absolute path")
    func getSetRoundTrip() {
        let dm = DataModel(.object(["count": .int(0)]))
        dm.set("/count", .int(42))
        #expect(dm.get("/count") == .int(42))
    }

    @Test("set nil removes key")
    func setNilRemoves() {
        let dm = DataModel(.object(["a": .int(1), "b": .int(2)]))
        dm.set("/a", nil)
        #expect(dm.get("/a") == nil)
        #expect(dm.get("/b") == .int(2))
    }

    @Test("subscribe fires current value synchronously")
    func subscribeFiresInitial() {
        let dm = DataModel(.object(["name": .string("Alice")]))
        var received: [StructuredValue?] = []
        let sub = dm.subscribe("/name") { received.append($0) }
        // Must have fired exactly once, synchronously, with the current value.
        #expect(received == [.string("Alice")])
        sub.cancel()
    }

    @Test("subscribe notified on direct write")
    func subscribeDirectWrite() {
        let dm = DataModel(.object(["name": .string("Alice")]))
        var received: [StructuredValue?] = []
        let sub = dm.subscribe("/name") { received.append($0) }
        dm.set("/name", .string("Bob"))
        #expect(received == [.string("Alice"), .string("Bob")])
        sub.cancel()
    }

    @Test("bubble: writing a child notifies an ancestor subscriber")
    func bubbleToAncestor() {
        let dm = DataModel(.object(["user": .object(["name": .string("Alice")])]))
        var received: [StructuredValue?] = []
        let sub = dm.subscribe("/user") { received.append($0) }
        dm.set("/user/name", .string("Bob"))
        // The /user subscriber should be notified with the updated subtree.
        #expect(received.count == 2)
        #expect(received.last == .object(["name": .string("Bob")]))
        sub.cancel()
    }

    @Test("cascade: writing a parent notifies a descendant subscriber")
    func cascadeToDescendant() {
        let dm = DataModel(.object(["user": .object(["name": .string("Alice")])]))
        var received: [StructuredValue?] = []
        let sub = dm.subscribe("/user/name") { received.append($0) }
        // Replace the whole /user subtree.
        dm.set("/user", .object(["name": .string("Carol")]))
        #expect(received.count == 2)
        #expect(received.last == .string("Carol"))
        sub.cancel()
    }

    @Test("unrelated path is not notified")
    func unrelatedNotNotified() {
        let dm = DataModel(.object(["a": .int(1), "b": .int(2)]))
        var received: [StructuredValue?] = []
        let sub = dm.subscribe("/a") { received.append($0) }
        dm.set("/b", .int(99))
        // Only the initial synchronous fire; /b is unrelated to /a.
        #expect(received == [.int(1)])
        sub.cancel()
    }

    @Test("cancel stops further notifications")
    func cancelStops() {
        let dm = DataModel(.object(["x": .int(0)]))
        var received: [StructuredValue?] = []
        let sub = dm.subscribe("/x") { received.append($0) }
        sub.cancel()
        dm.set("/x", .int(1))
        #expect(received == [.int(0)])
    }

    @Test("two-way binding reactivity: TextField + Text bound to same path")
    func twoWayReactivity() {
        // Spec example: a TextField bound to /user/name and a Text label bound to /user/name;
        // the label must update when the field updates the model.
        let dm = DataModel(.object(["user": .object(["name": .string("")])]))
        var labelValues: [String] = []
        let sub = dm.subscribe("/user/name") { labelValues.append(TypeCoercion.toString($0)) }
        // Simulate the field writing the model on each keystroke.
        dm.set("/user/name", .string("J"))
        dm.set("/user/name", .string("Ja"))
        dm.set("/user/name", .string("Jane"))
        #expect(labelValues == ["", "J", "Ja", "Jane"])
        sub.cancel()
    }
}
