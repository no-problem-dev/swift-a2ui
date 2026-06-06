import Foundation
import Testing

@testable import A2UICore

// MARK: - StructuredValue

@Suite("StructuredValue")
struct StructuredValueTests {
    @Test func roundTripNull() throws {
        let value: StructuredValue = .null
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(StructuredValue.self, from: data)
        #expect(decoded == .null)
    }

    @Test func roundTripBool() throws {
        let value: StructuredValue = .bool(true)
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(StructuredValue.self, from: data)
        #expect(decoded == .bool(true))
    }

    @Test func roundTripInt() throws {
        let value: StructuredValue = .int(42)
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(StructuredValue.self, from: data)
        #expect(decoded == .int(42))
    }

    @Test func roundTripDouble() throws {
        let value: StructuredValue = .double(3.14)
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(StructuredValue.self, from: data)
        #expect(decoded == .double(3.14))
    }

    @Test func roundTripString() throws {
        let value: StructuredValue = .string("hello")
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(StructuredValue.self, from: data)
        #expect(decoded == .string("hello"))
    }

    @Test func roundTripNestedObject() throws {
        let value: StructuredValue = .object([
            "name": .string("Alice"),
            "age": .int(30),
            "active": .bool(true),
        ])
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(StructuredValue.self, from: data)
        #expect(decoded == value)
    }

    @Test func expressibleByLiterals() {
        let s: StructuredValue = "hello"
        #expect(s == .string("hello"))
        let n: StructuredValue = 42
        #expect(n == .int(42))
        let b: StructuredValue = true
        #expect(b == .bool(true))
        let f: StructuredValue = 3.14
        #expect(f == .double(3.14))
    }
}

// MARK: - DataBinding

@Suite("DataBinding")
struct DataBindingTests {
    @Test func roundTrip() throws {
        let binding = DataBinding(path: "/user/name")
        let data = try JSONEncoder().encode(binding)
        let decoded = try JSONDecoder().decode(DataBinding.self, from: data)
        #expect(decoded.path == "/user/name")
    }

    @Test func decodesFromJSON() throws {
        let json = #"{"path": "/items/0/title"}"#
        let decoded = try JSONDecoder().decode(DataBinding.self, from: Data(json.utf8))
        #expect(decoded.path == "/items/0/title")
    }
}

// MARK: - FunctionCall

@Suite("FunctionCall")
struct FunctionCallTests {
    @Test func roundTrip() throws {
        let fc = FunctionCall(
            call: "formatDate",
            args: [
                "value": .object(["path": .string("/date")]),
                "format": .string("MMM dd, yyyy"),
            ],
            returnType: .string
        )
        let data = try JSONEncoder().encode(fc)
        let decoded = try JSONDecoder().decode(FunctionCall.self, from: data)
        #expect(decoded.call == "formatDate")
        #expect(decoded.returnType == .string)
    }

    @Test func minimalFunctionCall() throws {
        let json = #"{"call": "required", "args": {"value": "test"}}"#
        let decoded = try JSONDecoder().decode(FunctionCall.self, from: Data(json.utf8))
        #expect(decoded.call == "required")
        #expect(decoded.returnType == nil)
    }
}

// MARK: - DynamicString

@Suite("DynamicString")
struct DynamicStringTests {
    @Test func literalRoundTrip() throws {
        let ds: DynamicString = .literal("Hello")
        let data = try JSONEncoder().encode(ds)
        let decoded = try JSONDecoder().decode(DynamicString.self, from: data)
        #expect(decoded == .literal("Hello"))
    }

    @Test func bindingRoundTrip() throws {
        let ds: DynamicString = .binding(DataBinding(path: "/name"))
        let data = try JSONEncoder().encode(ds)
        let decoded = try JSONDecoder().decode(DynamicString.self, from: data)
        #expect(decoded == .binding(DataBinding(path: "/name")))
    }

    @Test func functionCallRoundTrip() throws {
        let fc = FunctionCall(call: "formatDate", args: ["value": .string("2025-01-01")], returnType: .string)
        let ds: DynamicString = .functionCall(fc)
        let data = try JSONEncoder().encode(ds)
        let decoded = try JSONDecoder().decode(DynamicString.self, from: data)
        if case .functionCall(let decodedFC) = decoded {
            #expect(decodedFC.call == "formatDate")
        } else {
            Issue.record("Expected .functionCall case")
        }
    }

    @Test func expressibleByStringLiteral() {
        let ds: DynamicString = "Hello World"
        #expect(ds == .literal("Hello World"))
    }

    @Test func decodesLiteralFromJSON() throws {
        let json = #""Hello""#
        let decoded = try JSONDecoder().decode(DynamicString.self, from: Data(json.utf8))
        #expect(decoded == .literal("Hello"))
    }

    @Test func decodesBindingFromJSON() throws {
        let json = #"{"path": "/user/name"}"#
        let decoded = try JSONDecoder().decode(DynamicString.self, from: Data(json.utf8))
        #expect(decoded == .binding(DataBinding(path: "/user/name")))
    }

    @Test func decodesFunctionCallFromJSON() throws {
        let json = #"{"call": "formatDate", "args": {"value": {"path": "/date"}, "format": "MMM dd"}, "returnType": "string"}"#
        let decoded = try JSONDecoder().decode(DynamicString.self, from: Data(json.utf8))
        if case .functionCall(let fc) = decoded {
            #expect(fc.call == "formatDate")
            #expect(fc.returnType == .string)
        } else {
            Issue.record("Expected .functionCall case")
        }
    }
}

// MARK: - DynamicNumber

@Suite("DynamicNumber")
struct DynamicNumberTests {
    @Test func literalRoundTrip() throws {
        let dn: DynamicNumber = .literal(42.5)
        let data = try JSONEncoder().encode(dn)
        let decoded = try JSONDecoder().decode(DynamicNumber.self, from: data)
        #expect(decoded == .literal(42.5))
    }

    @Test func bindingRoundTrip() throws {
        let dn: DynamicNumber = .binding(DataBinding(path: "/count"))
        let data = try JSONEncoder().encode(dn)
        let decoded = try JSONDecoder().decode(DynamicNumber.self, from: data)
        #expect(decoded == .binding(DataBinding(path: "/count")))
    }

    @Test func expressibleByLiterals() {
        let fromFloat: DynamicNumber = 3.14
        #expect(fromFloat == .literal(3.14))
        let fromInt: DynamicNumber = 42
        #expect(fromInt == .literal(42.0))
    }
}

// MARK: - DynamicBoolean

@Suite("DynamicBoolean")
struct DynamicBooleanTests {
    @Test func literalRoundTrip() throws {
        let db: DynamicBoolean = .literal(true)
        let data = try JSONEncoder().encode(db)
        let decoded = try JSONDecoder().decode(DynamicBoolean.self, from: data)
        #expect(decoded == .literal(true))
    }

    @Test func expressibleByBooleanLiteral() {
        let db: DynamicBoolean = false
        #expect(db == .literal(false))
    }
}

// MARK: - DynamicStringList

@Suite("DynamicStringList")
struct DynamicStringListTests {
    @Test func literalRoundTrip() throws {
        let dsl: DynamicStringList = .literal(["a", "b", "c"])
        let data = try JSONEncoder().encode(dsl)
        let decoded = try JSONDecoder().decode(DynamicStringList.self, from: data)
        #expect(decoded == .literal(["a", "b", "c"]))
    }

    @Test func bindingRoundTrip() throws {
        let dsl: DynamicStringList = .binding(DataBinding(path: "/tags"))
        let data = try JSONEncoder().encode(dsl)
        let decoded = try JSONDecoder().decode(DynamicStringList.self, from: data)
        #expect(decoded == .binding(DataBinding(path: "/tags")))
    }
}

// MARK: - DynamicValue

@Suite("DynamicValue")
struct DynamicValueTests {
    @Test func decodesString() throws {
        let json = #""hello""#
        let decoded = try JSONDecoder().decode(DynamicValue.self, from: Data(json.utf8))
        #expect(decoded == .string("hello"))
    }

    @Test func decodesNumber() throws {
        let json = "42.5"
        let decoded = try JSONDecoder().decode(DynamicValue.self, from: Data(json.utf8))
        #expect(decoded == .number(42.5))
    }

    @Test func decodesBooleanTrue() throws {
        let json = "true"
        let decoded = try JSONDecoder().decode(DynamicValue.self, from: Data(json.utf8))
        #expect(decoded == .boolean(true))
    }

    @Test func decodesBooleanFalse() throws {
        let json = "false"
        let decoded = try JSONDecoder().decode(DynamicValue.self, from: Data(json.utf8))
        #expect(decoded == .boolean(false))
    }

    @Test func decodesBinding() throws {
        let json = #"{"path": "/x"}"#
        let decoded = try JSONDecoder().decode(DynamicValue.self, from: Data(json.utf8))
        #expect(decoded == .binding(DataBinding(path: "/x")))
    }

    @Test func decodesFunctionCall() throws {
        let json = #"{"call": "required", "args": {"value": "test"}}"#
        let decoded = try JSONDecoder().decode(DynamicValue.self, from: Data(json.utf8))
        if case .functionCall(let fc) = decoded {
            #expect(fc.call == "required")
        } else {
            Issue.record("Expected .functionCall case")
        }
    }
}

// MARK: - ChildList

@Suite("ChildList")
struct ChildListTests {
    @Test func idsRoundTrip() throws {
        let cl: ChildList = .ids(["child1", "child2", "child3"])
        let data = try JSONEncoder().encode(cl)
        let decoded = try JSONDecoder().decode(ChildList.self, from: data)
        #expect(decoded == .ids(["child1", "child2", "child3"]))
    }

    @Test func templateRoundTrip() throws {
        let cl: ChildList = .template(componentId: "item-row", path: "/items")
        let data = try JSONEncoder().encode(cl)
        let decoded = try JSONDecoder().decode(ChildList.self, from: data)
        #expect(decoded == .template(componentId: "item-row", path: "/items"))
    }

    @Test func decodesArrayFromJSON() throws {
        let json = #"["a", "b", "c"]"#
        let decoded = try JSONDecoder().decode(ChildList.self, from: Data(json.utf8))
        #expect(decoded == .ids(["a", "b", "c"]))
    }

    @Test func decodesTemplateFromJSON() throws {
        let json = #"{"componentId": "row-template", "path": "/data/rows"}"#
        let decoded = try JSONDecoder().decode(ChildList.self, from: Data(json.utf8))
        #expect(decoded == .template(componentId: "row-template", path: "/data/rows"))
    }
}

// MARK: - Action

@Suite("Action")
struct ActionTests {
    @Test func eventRoundTrip() throws {
        let action: Action = .event(EventAction(
            name: "submit",
            context: ["email": .binding(DataBinding(path: "/email"))]
        ))
        let data = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(Action.self, from: data)
        if case .event(let ea) = decoded {
            #expect(ea.name == "submit")
            #expect(ea.context?["email"] == .binding(DataBinding(path: "/email")))
        } else {
            Issue.record("Expected .event case")
        }
    }

    @Test func functionCallRoundTrip() throws {
        let action: Action = .functionCall(FunctionCall(
            call: "openUrl",
            args: ["url": .string("https://example.com")],
            returnType: .void
        ))
        let data = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(Action.self, from: data)
        if case .functionCall(let fc) = decoded {
            #expect(fc.call == "openUrl")
        } else {
            Issue.record("Expected .functionCall case")
        }
    }

    @Test func decodesEventFromJSON() throws {
        let json = #"{"event": {"name": "click", "context": {"id": "btn-1"}}}"#
        let decoded = try JSONDecoder().decode(Action.self, from: Data(json.utf8))
        if case .event(let ea) = decoded {
            #expect(ea.name == "click")
        } else {
            Issue.record("Expected .event case")
        }
    }

    @Test func decodesFunctionCallFromJSON() throws {
        let json = #"{"functionCall": {"call": "openUrl", "args": {"url": "https://example.com"}}}"#
        let decoded = try JSONDecoder().decode(Action.self, from: Data(json.utf8))
        if case .functionCall(let fc) = decoded {
            #expect(fc.call == "openUrl")
        } else {
            Issue.record("Expected .functionCall case")
        }
    }
}

// MARK: - CheckRule

@Suite("CheckRule")
struct CheckRuleTests {
    @Test func roundTrip() throws {
        let rule = CheckRule(
            condition: .functionCall(FunctionCall(call: "required", args: ["value": .string("test")], returnType: .boolean)),
            message: "Field is required"
        )
        let data = try JSONEncoder().encode(rule)
        let decoded = try JSONDecoder().decode(CheckRule.self, from: data)
        #expect(decoded.message == "Field is required")
    }
}

// MARK: - ServerMessage

@Suite("ServerMessage")
struct ServerMessageTests {
    @Test func createSurfaceRoundTrip() throws {
        let msg: ServerMessage = .createSurface(CreateSurface(
            surfaceId: "s1",
            catalogId: "https://a2ui.org/basic",
            sendDataModel: true
        ))
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ServerMessage.self, from: data)
        if case .createSurface(let cs) = decoded {
            #expect(cs.surfaceId == "s1")
            #expect(cs.catalogId == "https://a2ui.org/basic")
            #expect(cs.sendDataModel == true)
        } else {
            Issue.record("Expected .createSurface case")
        }
    }

    @Test func updateComponentsRoundTrip() throws {
        let msg: ServerMessage = .updateComponents(UpdateComponents(
            surfaceId: "s1",
            components: [
                .object(["id": .string("root"), "component": .string("Card"), "child": .string("col")])
            ]
        ))
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ServerMessage.self, from: data)
        if case .updateComponents(let uc) = decoded {
            #expect(uc.surfaceId == "s1")
            #expect(uc.components.count == 1)
        } else {
            Issue.record("Expected .updateComponents case")
        }
    }

    @Test func updateDataModelRoundTrip() throws {
        let msg: ServerMessage = .updateDataModel(UpdateDataModel(
            surfaceId: "s1",
            path: "/user/name",
            value: .string("Alice")
        ))
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ServerMessage.self, from: data)
        if case .updateDataModel(let udm) = decoded {
            #expect(udm.surfaceId == "s1")
            #expect(udm.path == "/user/name")
            #expect(udm.value == .string("Alice"))
        } else {
            Issue.record("Expected .updateDataModel case")
        }
    }

    @Test func deleteSurfaceRoundTrip() throws {
        let msg: ServerMessage = .deleteSurface(DeleteSurface(surfaceId: "s1"))
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ServerMessage.self, from: data)
        if case .deleteSurface(let ds) = decoded {
            #expect(ds.surfaceId == "s1")
        } else {
            Issue.record("Expected .deleteSurface case")
        }
    }

    @Test func decodesCreateSurfaceFromJSON() throws {
        let json = """
        {"version": "v0.10", "createSurface": {"surfaceId": "booking", "catalogId": "https://a2ui.org/specification/v0_10/catalogs/basic/catalog.json"}}
        """
        let decoded = try JSONDecoder().decode(ServerMessage.self, from: Data(json.utf8))
        if case .createSurface(let cs) = decoded {
            #expect(cs.surfaceId == "booking")
        } else {
            Issue.record("Expected .createSurface case")
        }
    }

    @Test func decodesUpdateDataModelWithFullValue() throws {
        let json = """
        {"version": "v0.10", "updateDataModel": {"surfaceId": "s1", "value": {"name": "Alice", "age": 30}}}
        """
        let decoded = try JSONDecoder().decode(ServerMessage.self, from: Data(json.utf8))
        if case .updateDataModel(let udm) = decoded {
            #expect(udm.surfaceId == "s1")
            #expect(udm.path == nil)
        } else {
            Issue.record("Expected .updateDataModel case")
        }
    }

    @Test func rejectsUnknownVersion() {
        let json = """
        {"version": "v0.8", "createSurface": {"surfaceId": "s1", "catalogId": "x"}}
        """
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ServerMessage.self, from: Data(json.utf8))
        }
    }

}

// MARK: - ClientMessage

@Suite("ClientMessage")
struct ClientMessageTests {
    @Test func actionRoundTrip() throws {
        let msg: ClientMessage = .action(UserAction(
            name: "submit",
            surfaceId: "s1",
            sourceComponentId: "btn-1",
            timestamp: "2025-12-16T14:30:00Z",
            context: ["email": .string("user@example.com")]
        ))
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ClientMessage.self, from: data)
        if case .action(let action) = decoded {
            #expect(action.name == "submit")
            #expect(action.surfaceId == "s1")
            #expect(action.sourceComponentId == "btn-1")
        } else {
            Issue.record("Expected .action case")
        }
    }

    @Test func errorRoundTrip() throws {
        let msg: ClientMessage = .error(ClientError(
            code: "VALIDATION_FAILED",
            surfaceId: "s1",
            message: "Expected string, got integer",
            path: "/components/0/text"
        ))
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ClientMessage.self, from: data)
        if case .error(let err) = decoded {
            #expect(err.code == "VALIDATION_FAILED")
            #expect(err.path == "/components/0/text")
        } else {
            Issue.record("Expected .error case")
        }
    }
}

// MARK: - Official Example JSON Decoding

@Suite("Official Examples")
struct OfficialExampleTests {

    struct ExampleFile: Codable {
        let name: String
        let description: String
        let messages: [ServerMessage]
    }

    @Test func decodesFlightStatusExample() throws {
        let url = Bundle.module.url(forResource: "01_flight-status", withExtension: "json", subdirectory: "Fixtures")!
        let data = try Data(contentsOf: url)
        let example = try JSONDecoder().decode(ExampleFile.self, from: data)
        #expect(example.name == "Flight Status")
        #expect(example.messages.count == 3)

        if case .createSurface(let cs) = example.messages[0] {
            #expect(cs.surfaceId == "gallery-flight-status")
            #expect(cs.sendDataModel == true)
        } else {
            Issue.record("First message should be createSurface")
        }

        if case .updateComponents(let uc) = example.messages[1] {
            #expect(uc.components.count == 22)
        } else {
            Issue.record("Second message should be updateComponents")
        }

        if case .updateDataModel(let udm) = example.messages[2] {
            #expect(udm.surfaceId == "gallery-flight-status")
        } else {
            Issue.record("Third message should be updateDataModel")
        }
    }

    @Test func decodesLoginFormExample() throws {
        let url = Bundle.module.url(forResource: "09_login-form", withExtension: "json", subdirectory: "Fixtures")!
        let data = try Data(contentsOf: url)
        let example = try JSONDecoder().decode(ExampleFile.self, from: data)
        #expect(example.name == "Login Form with Validation")
        #expect(example.messages.count >= 2)
    }

    @Test func decodesChildListTemplateExample() throws {
        let url = Bundle.module.url(forResource: "34_child-list-template", withExtension: "json", subdirectory: "Fixtures")!
        let data = try Data(contentsOf: url)
        let example = try JSONDecoder().decode(ExampleFile.self, from: data)
        #expect(example.messages.count >= 2)
    }
}
