import Testing
@testable import A2UISurface
import A2UICore

// MARK: - JSONPointer Tests

@Suite("JSONPointer")
struct JSONPointerTests {

    // MARK: resolve

    @Test("resolve absolute path - top level key")
    func resolveTopLevel() {
        let data: AnyCodable = .object(["name": .string("Alice"), "age": .int(30)])
        let result = JSONPointer.resolve(path: "/name", in: data)
        #expect(result == .string("Alice"))
    }

    @Test("resolve absolute path - nested key")
    func resolveNested() {
        let data: AnyCodable = .object([
            "user": .object(["email": .string("a@b.com")])
        ])
        let result = JSONPointer.resolve(path: "/user/email", in: data)
        #expect(result == .string("a@b.com"))
    }

    @Test("resolve array index")
    func resolveArrayIndex() {
        let data: AnyCodable = .object(["items": .array([.string("x"), .string("y"), .string("z")])])
        let result = JSONPointer.resolve(path: "/items/1", in: data)
        #expect(result == .string("y"))
    }

    @Test("resolve returns nil for non-existent path")
    func resolveNonExistent() {
        let data: AnyCodable = .object(["a": .string("b")])
        let result = JSONPointer.resolve(path: "/missing", in: data)
        #expect(result == nil)
    }

    @Test("resolve returns nil for out-of-bounds array index")
    func resolveOutOfBounds() {
        let data: AnyCodable = .array([.int(1), .int(2)])
        let result = JSONPointer.resolve(path: "/5", in: data)
        #expect(result == nil)
    }

    @Test("resolve '/' path returns the document root (RFC 6901: empty pointer)")
    func resolveEmptyPath() {
        let data: AnyCodable = .string("root-value")
        // "/" strips the leading slash leaving an empty string → zero tokens → returns root as-is
        let result = JSONPointer.resolve(path: "/", in: data)
        #expect(result == .string("root-value"))
    }

    // MARK: set

    @Test("set top level value")
    func setTopLevel() {
        var data: AnyCodable = .object(["x": .int(1)])
        JSONPointer.set(path: "/x", value: .int(99), in: &data)
        #expect(JSONPointer.resolve(path: "/x", in: data) == .int(99))
    }

    @Test("set nested value creates intermediate objects")
    func setNestedCreatesIntermediate() {
        var data: AnyCodable = .object([:])
        JSONPointer.set(path: "/a/b/c", value: .string("deep"), in: &data)
        #expect(JSONPointer.resolve(path: "/a/b/c", in: data) == .string("deep"))
    }

    @Test("set with empty path replaces entire value")
    func setEmptyPathReplacesRoot() {
        var data: AnyCodable = .object(["old": .bool(true)])
        JSONPointer.set(path: "", value: .string("replaced"), in: &data)
        #expect(data == .string("replaced"))
    }

    @Test("set array element by index")
    func setArrayElement() {
        var data: AnyCodable = .object(["list": .array([.int(1), .int(2), .int(3)])])
        JSONPointer.set(path: "/list/0", value: .int(99), in: &data)
        #expect(JSONPointer.resolve(path: "/list/0", in: data) == .int(99))
    }

    // MARK: remove

    @Test("remove top level key")
    func removeTopLevel() {
        var data: AnyCodable = .object(["a": .int(1), "b": .int(2)])
        JSONPointer.remove(path: "/a", in: &data)
        #expect(JSONPointer.resolve(path: "/a", in: data) == nil)
        #expect(JSONPointer.resolve(path: "/b", in: data) == .int(2))
    }

    @Test("remove nested key")
    func removeNested() {
        var data: AnyCodable = .object([
            "user": .object(["name": .string("Alice"), "age": .int(30)])
        ])
        JSONPointer.remove(path: "/user/age", in: &data)
        #expect(JSONPointer.resolve(path: "/user/age", in: data) == nil)
        #expect(JSONPointer.resolve(path: "/user/name", in: data) == .string("Alice"))
    }

    @Test("remove non-existent path is a no-op")
    func removeNonExistentIsNoOp() {
        var data: AnyCodable = .object(["a": .int(1)])
        JSONPointer.remove(path: "/missing", in: &data)
        #expect(JSONPointer.resolve(path: "/a", in: data) == .int(1))
    }

    // MARK: escape sequences

    @Test("RFC 6901 escape: ~1 decodes to /")
    func escapeSlash() {
        let data: AnyCodable = .object(["a/b": .string("slash")])
        let result = JSONPointer.resolve(path: "/a~1b", in: data)
        #expect(result == .string("slash"))
    }

    @Test("RFC 6901 escape: ~0 decodes to ~")
    func escapeTilde() {
        let data: AnyCodable = .object(["a~b": .string("tilde")])
        let result = JSONPointer.resolve(path: "/a~0b", in: data)
        #expect(result == .string("tilde"))
    }
}

// MARK: - ComponentTreeResolver Tests

@Suite("ComponentTreeResolver")
struct ComponentTreeResolverTests {

    @Test("simple two-level tree")
    func simpleTree() throws {
        let components: [String: AnyCodable] = [
            "root": .object(["id": .string("root"), "children": .array([.string("child1")])]),
            "child1": .object(["id": .string("child1")])
        ]
        let tree = try ComponentTreeResolver.resolve(components: components)
        #expect(tree.id == "root")
        #expect(tree.children.count == 1)
        #expect(tree.children[0].id == "child1")
    }

    @Test("missing root throws missingRoot")
    func missingRoot() {
        let components: [String: AnyCodable] = [
            "btn": .object(["id": .string("btn")])
        ]
        #expect(throws: ComponentTreeResolver.TreeError.missingRoot) {
            try ComponentTreeResolver.resolve(components: components)
        }
    }

    @Test("circular reference throws circularReference")
    func circularReference() {
        let components: [String: AnyCodable] = [
            "root": .object(["id": .string("root"), "children": .array([.string("a")])]),
            "a": .object(["id": .string("a"), "children": .array([.string("root")])])
        ]
        #expect(throws: ComponentTreeResolver.TreeError.circularReference("root")) {
            try ComponentTreeResolver.resolve(components: components)
        }
    }

    @Test("depth limit exceeded throws depthLimitExceeded")
    func depthLimit() throws {
        // Build a chain 51 nodes deep: root -> n0 -> n1 -> ... -> n49
        var components: [String: AnyCodable] = [:]
        components["root"] = .object(["id": .string("root"), "child": .string("n0")])
        for i in 0..<(ComponentTreeResolver.maxDepth) {
            let id = "n\(i)"
            let nextId = "n\(i + 1)"
            components[id] = .object(["id": .string(id), "child": .string(nextId)])
        }
        components["n\(ComponentTreeResolver.maxDepth)"] = .object(["id": .string("n\(ComponentTreeResolver.maxDepth)")])

        #expect(throws: ComponentTreeResolver.TreeError.depthLimitExceeded(ComponentTreeResolver.maxDepth)) {
            try ComponentTreeResolver.resolve(components: components)
        }
    }

    @Test("tabs child extraction")
    func tabsChildExtraction() throws {
        let components: [String: AnyCodable] = [
            "root": .object([
                "id": .string("root"),
                "tabs": .array([
                    .object(["child": .string("tab1")]),
                    .object(["child": .string("tab2")])
                ])
            ]),
            "tab1": .object(["id": .string("tab1")]),
            "tab2": .object(["id": .string("tab2")])
        ]
        let tree = try ComponentTreeResolver.resolve(components: components)
        #expect(tree.children.count == 2)
        let childIds = Set(tree.children.map { $0.id })
        #expect(childIds == ["tab1", "tab2"])
    }

    @Test("modal trigger and content extraction")
    func modalTriggerContentExtraction() throws {
        let components: [String: AnyCodable] = [
            "root": .object([
                "id": .string("root"),
                "trigger": .string("btn"),
                "content": .string("body")
            ]),
            "btn": .object(["id": .string("btn")]),
            "body": .object(["id": .string("body")])
        ]
        let tree = try ComponentTreeResolver.resolve(components: components)
        let childIds = Set(tree.children.map { $0.id })
        #expect(childIds.contains("btn"))
        #expect(childIds.contains("body"))
    }

    @Test("empty components dictionary throws missingRoot")
    func emptyComponents() {
        #expect(throws: ComponentTreeResolver.TreeError.missingRoot) {
            try ComponentTreeResolver.resolve(components: [:])
        }
    }
}

// MARK: - ComponentValidator Tests

@Suite("ComponentValidator")
struct ComponentValidatorTests {

    @Test("duplicate IDs throw duplicateId")
    func duplicateIds() {
        let components: [AnyCodable] = [
            .object(["id": .string("btn"), "type": .string("button")]),
            .object(["id": .string("btn"), "type": .string("button")])
        ]
        #expect(throws: ComponentValidator.ValidationError.duplicateId("btn")) {
            try ComponentValidator.validateUniqueIds(components: components)
        }
    }

    @Test("missing root throws missingRoot in topology validation")
    func missingRootTopology() {
        let components: [String: AnyCodable] = [
            "btn": .object(["id": .string("btn")])
        ]
        #expect(throws: ComponentValidator.ValidationError.missingRoot) {
            try ComponentValidator.validateTopology(components: components)
        }
    }

    @Test("valid components pass without throwing")
    func validComponents() throws {
        let components: [AnyCodable] = [
            .object(["id": .string("root")]),
            .object(["id": .string("header")]),
            .object(["id": .string("footer")])
        ]
        try ComponentValidator.validateUniqueIds(components: components)

        let topologyComponents: [String: AnyCodable] = [
            "root": .object(["id": .string("root"), "children": .array([.string("header")])])
        ]
        try ComponentValidator.validateTopology(components: topologyComponents)
    }

    @Test("circular reference propagates as circularReference error")
    func circularReferenceInTopology() {
        let components: [String: AnyCodable] = [
            "root": .object(["id": .string("root"), "child": .string("a")]),
            "a": .object(["id": .string("a"), "child": .string("root")])
        ]
        #expect(throws: ComponentValidator.ValidationError.circularReference("root")) {
            try ComponentValidator.validateTopology(components: components)
        }
    }
}
