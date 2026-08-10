import StructuredDataCore
import Foundation
import Testing
import A2ACore
import A2UICore

@testable import A2UIA2A

// MARK: - A2UIExtension

@Suite("A2UIExtension")
struct A2UIExtensionTests {
    @Test func uriMatchesOfficialFormat() {
        // {base}/v{version} — official extension.py format, with our hard-cut version.
        #expect(A2UIExtension.uri == "https://a2ui.org/a2a-extension/a2ui/v1.0")
    }

    @Test func paramKeysMatchOfficialConstants() {
        #expect(A2UIExtension.supportedCatalogIdsKey == "supportedCatalogIds")
        #expect(A2UIExtension.acceptsInlineCatalogsKey == "acceptsInlineCatalogs")
    }

    @Test func agentExtensionCarriesParams() {
        let ext = A2UIExtension.agentExtension(
            supportedCatalogIds: ["https://example.com/catalog.json"],
            acceptsInlineCatalogs: true
        )
        #expect(ext.uri == A2UIExtension.uri)
        #expect(ext.params?["supportedCatalogIds"]?.arrayValue?.compactMap(\.stringValue)
                == ["https://example.com/catalog.json"])
        #expect(ext.params?["acceptsInlineCatalogs"]?.boolValue == true)
    }

    @Test func agentExtensionOmitsEmptyParams() {
        // Official get_a2ui_agent_extension passes params=None when nothing is set.
        #expect(A2UIExtension.agentExtension().params == nil)
    }

    @Test func declarationsRoundTripThroughAgentCard() throws {
        let card = AgentCard(
            name: "researcher",
            description: "Research agent",
            supportedInterfaces: [AgentInterface(url: "inprocess://researcher", protocolBinding: "InProcess")],
            version: "1.0.0",
            capabilities: AgentCapabilities(
                streaming: true,
                extensions: [
                    A2UIExtension.agentExtension(supportedCatalogIds: ["cat-a", "cat-b"]),
                    AgentExtension(uri: "https://example.com/other-extension/v1"),
                ]
            )
        )
        let data = try JSONEncoder().encode(card)
        let decoded = try JSONDecoder().decode(AgentCard.self, from: data)

        let declarations = A2UIExtension.declarations(in: decoded)
        #expect(declarations.count == 1)
        #expect(declarations.first?.version == "v1.0")
        #expect(declarations.first?.supportedCatalogIds == ["cat-a", "cat-b"])
        #expect(declarations.first?.acceptsInlineCatalogs == false)

        let current = A2UIExtension.currentDeclaration(in: decoded)
        #expect(current == declarations.first)
    }

    @Test func nonA2UIExtensionsAreIgnored() {
        let card = AgentCard(
            name: "plain",
            description: "No A2UI",
            supportedInterfaces: [AgentInterface(url: "inprocess://plain", protocolBinding: "InProcess")],
            version: "1.0.0",
            capabilities: AgentCapabilities(extensions: [
                AgentExtension(uri: "https://example.com/other-extension/v1"),
            ])
        )
        #expect(A2UIExtension.declarations(in: card).isEmpty)
        #expect(A2UIExtension.currentDeclaration(in: card) == nil)
    }
}

// MARK: - A2UI Part coding

@Suite("A2UIPart")
struct A2UIPartTests {
    private func makeServerMessage() -> AgentMessage {
        .createSurface(CreateSurface(
            surfaceId: "surface_1",
            catalogId: "https://example.com/catalog.json",
            dataModel: .object(["title": .string("hello")])
        ))
    }

    private func makeUserAction() -> UserAction {
        UserAction(
            name: "book_restaurant",
            surfaceId: "surface_1",
            sourceComponentId: "button_3",
            timestamp: "2026-06-07T12:00:00Z",
            context: ["restaurantName": .string("Sushi Dai")]
        )
    }

    @Test func serverMessageRoundTripsThroughPartJSON() throws {
        let message = makeServerMessage()
        let part = try Part.a2ui(message)
        #expect(part.mediaType == A2UIMediaType.a2uiJSON)
        #expect(part.isA2UI)

        let data = try JSONEncoder().encode(part)
        let decoded = try JSONDecoder().decode(Part.self, from: data)
        #expect(decoded.isA2UI)
        #expect(try decoded.a2uiAgentMessage() == message)
    }

    @Test func wireShapeCarriesVersionEnvelope() throws {
        let part = try Part.a2ui(makeServerMessage())
        let data = try JSONEncoder().encode(part)
        let json = try JSONDecoder().decode(StructuredValue.self, from: data)
        // v1.0 wire format: every A2UI message is version-enveloped inside the data part.
        #expect(json["data"]["version"].stringValue == "v1.0")
        #expect(json["data"]["createSurface"]["surfaceId"].stringValue == "surface_1")
        #expect(json["mediaType"].stringValue == "application/a2ui+json")
    }

    @Test func clientMessageRoundTripsAndExposesUserAction() throws {
        let action = makeUserAction()
        let part = try Part.a2ui(RendererMessage.action(action))

        let data = try JSONEncoder().encode(part)
        let decoded = try JSONDecoder().decode(Part.self, from: data)
        #expect(try decoded.a2uiRendererMessage() == .action(action))
        #expect(decoded.a2uiUserAction?.surfaceId == "surface_1")
        #expect(decoded.a2uiUserAction?.name == "book_restaurant")
    }

    @Test func plainDataPartIsNotA2UI() throws {
        let part = Part.data(.object(["foo": .string("bar")]))
        #expect(!part.isA2UI)
        #expect(try part.a2uiAgentMessage() == nil)
        #expect(try part.a2uiRendererMessage() == nil)
        #expect(part.a2uiUserAction == nil)
    }

    @Test func textPartIsNotA2UI() throws {
        let part = Part.text("just text")
        #expect(!part.isA2UI)
        #expect(try part.a2uiAgentMessage() == nil)
    }

    @Test func metadataMimeTypeTagIsAccepted() throws {
        // The official v0.x SDK tags via part metadata["mimeType"], not Part.mediaType.
        let value = try StructuredValue.encoded(makeServerMessage())
        let part = Part.data(value, metadata: [A2UIMediaType.metadataKey: .string(A2UIMediaType.a2uiJSON)])
        #expect(part.isA2UI)
        #expect(try part.a2uiAgentMessage() == makeServerMessage())
    }

    @Test func malformedA2UIPartThrowsOnDecodeButReadsAsNoUserAction() {
        let part = Part.data(.object(["nonsense": .bool(true)]), mediaType: A2UIMediaType.a2uiJSON)
        #expect(throws: (any Error).self) { try part.a2uiAgentMessage() }
        // Routing reads a malformed action as "no action" and falls back to LLM routing.
        #expect(part.a2uiUserAction == nil)
    }
}

// MARK: - Message metadata vocabulary

@Suite("A2UIMessageMetadata")
struct A2UIMessageMetadataTests {
    @Test func keysMatchOfficialConstants() {
        #expect(A2UIMessageMetadata.rendererCapabilitiesKey == "a2uiRendererCapabilities")
        #expect(A2UIMessageMetadata.rendererDataModelKey == "a2uiRendererDataModel")
    }

    @Test func capabilitiesRoundTripThroughMetadata() throws {
        var metadata: A2AMetadata = [:]
        let capabilities = A2UIRendererCapabilities(supportedCatalogIds: ["cat-a"])
        try A2UIMessageMetadata.embed(capabilities, into: &metadata)

        #expect(A2UIMessageMetadata.rendererCapabilities(in: metadata) == capabilities)
        // v1.0: capabilities はバージョンキー配下に入れ子になる。
        #expect(
            metadata["a2uiRendererCapabilities"]?["v1.0"]["supportedCatalogIds"][0].stringValue == "cat-a")
    }

    /// v1.0 以前の平坦な形も読めること（Postel: 受け取りは寛容に）。
    @Test func capabilitiesDecodeToleratesUnversionedShape() throws {
        let metadata: A2AMetadata = [
            "a2uiRendererCapabilities": .object(["supportedCatalogIds": .array([.string("cat-a")])])
        ]
        #expect(
            A2UIMessageMetadata.rendererCapabilities(in: metadata)
                == A2UIRendererCapabilities(supportedCatalogIds: ["cat-a"]))
    }

    @Test func dataModelRoundTripThroughMetadata() throws {
        var metadata: A2AMetadata = [:]
        let dataModel = A2UIRendererDataModel(surfaces: [
            "surface_1": .object(["title": .string("hello")]),
            "surface_2": .object(["count": .int(3)]),
        ])
        try A2UIMessageMetadata.embed(dataModel, into: &metadata)

        #expect(A2UIMessageMetadata.rendererDataModel(in: metadata) == dataModel)
        // v1.0: データモデル側は `version` を平坦に持つ（capabilities のような入れ子ではない）。
        #expect(metadata["a2uiRendererDataModel"]?["version"].stringValue == "v1.0")
    }

    @Test func keepingStripsUnownedSurfaces() {
        let dataModel = A2UIRendererDataModel(surfaces: [
            "owned": .object(["a": .int(1)]),
            "foreign": .object(["b": .int(2)]),
        ])
        let stripped = dataModel.keeping(["owned"])
        #expect(stripped.surfaces.keys.sorted() == ["owned"])
        #expect(stripped.surfaces["owned"] == dataModel.surfaces["owned"])
    }

    @Test func absentMetadataReadsAsNil() {
        #expect(A2UIMessageMetadata.rendererCapabilities(in: nil) == nil)
        #expect(A2UIMessageMetadata.rendererDataModel(in: [:]) == nil)
    }
}
