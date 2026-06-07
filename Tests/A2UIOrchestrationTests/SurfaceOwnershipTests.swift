import Foundation
import Testing
import A2ACore
import A2UICore
import A2UIA2A

@testable import A2UIOrchestration

private func createSurfacePart(_ surfaceId: String) throws -> Part {
    try .a2ui(.createSurface(CreateSurface(surfaceId: surfaceId, catalogId: "cat")))
}

private func userActionPart(surfaceId: String, name: String = "tap") throws -> Part {
    try .a2ui(.action(UserAction(
        name: name,
        surfaceId: surfaceId,
        sourceComponentId: "button_1",
        timestamp: "2026-06-07T12:00:00Z",
        context: [:]
    )))
}

// MARK: - Ledger

@Suite("SurfaceOwnership ledger")
struct SurfaceOwnershipLedgerTests {
    @Test func recordsAndLooksUpOwner() {
        var ownership = SurfaceOwnership()
        ownership.record(owner: "researcher", of: "surface_1")
        #expect(ownership.owner(of: "surface_1") == "researcher")
        #expect(ownership.owner(of: "unknown") == nil)
    }

    @Test func lastWriterWins() {
        var ownership = SurfaceOwnership()
        ownership.record(owner: "researcher", of: "surface_1")
        ownership.record(owner: "coder", of: "surface_1")
        #expect(ownership.owner(of: "surface_1") == "coder")
    }

    @Test func surfaceIdsOwnedByFiltersPerAgent() {
        var ownership = SurfaceOwnership()
        ownership.record(owner: "researcher", of: "surface_1")
        ownership.record(owner: "researcher", of: "surface_2")
        ownership.record(owner: "coder", of: "surface_3")
        #expect(ownership.surfaceIds(ownedBy: "researcher") == ["surface_1", "surface_2"])
        #expect(ownership.surfaceIds(ownedBy: "visualizer").isEmpty)
    }
}

// MARK: - Recording from parts

@Suite("SurfaceOwnership recording")
struct SurfaceOwnershipRecordingTests {
    @Test func recordsEveryCreatedSurface() throws {
        var ownership = SurfaceOwnership()
        let parts: [Part] = [
            .text("Here are your results."),
            try createSurfacePart("surface_1"),
            try .a2ui(.updateDataModel(UpdateDataModel(surfaceId: "surface_1", value: .object([:])))),
            try createSurfacePart("surface_2"),
        ]
        ownership.record(surfacesCreatedIn: parts, by: "researcher")
        #expect(ownership.owner(of: "surface_1") == "researcher")
        #expect(ownership.owner(of: "surface_2") == "researcher")
    }

    @Test func ignoresNonCreationAndNonA2UIParts() {
        var ownership = SurfaceOwnership()
        let parts: [Part] = [
            .text("plain"),
            .data(.object(["foo": .string("bar")])),
        ]
        ownership.record(surfacesCreatedIn: parts, by: "researcher")
        #expect(ownership == SurfaceOwnership())
    }
}

// MARK: - Deterministic routing

@Suite("SurfaceOwnership routing")
struct SurfaceOwnershipRoutingTests {
    private func makeOwnership() -> SurfaceOwnership {
        var ownership = SurfaceOwnership()
        ownership.record(owner: "researcher", of: "surface_1")
        return ownership
    }

    @Test func routesTrailingUserActionToOwner() throws {
        let parts: [Part] = [.text("context"), try userActionPart(surfaceId: "surface_1")]
        #expect(makeOwnership().owner(ofUserActionIn: parts) == "researcher")
    }

    @Test func unknownSurfaceFallsBackToNil() throws {
        let parts: [Part] = [try userActionPart(surfaceId: "surface_99")]
        #expect(makeOwnership().owner(ofUserActionIn: parts) == nil)
    }

    @Test func onlyTrailingPartIsConsidered() throws {
        // Official before_model_callback reads contents[-1].parts[-1] only.
        let parts: [Part] = [try userActionPart(surfaceId: "surface_1"), .text("afterthought")]
        #expect(makeOwnership().owner(ofUserActionIn: parts) == nil)
    }

    @Test func plainTextMessageIsNotRouted() {
        #expect(makeOwnership().owner(ofUserActionIn: [.text("hello")]) == nil)
        #expect(makeOwnership().owner(ofUserActionIn: []) == nil)
    }
}

// MARK: - Outbound metadata

@Suite("SurfaceOwnership outbound metadata")
struct SurfaceOwnershipOutboundTests {
    private func makeOwnership() -> SurfaceOwnership {
        var ownership = SurfaceOwnership()
        ownership.record(owner: "researcher", of: "owned")
        ownership.record(owner: "coder", of: "foreign")
        return ownership
    }

    @Test func embedsCapabilitiesAndStripsDataModel() throws {
        var base: A2AMetadata = [:]
        try A2UIMessageMetadata.embed(A2UIClientDataModel(surfaces: [
            "owned": .object(["a": .int(1)]),
            "foreign": .object(["b": .int(2)]),
        ]), into: &base)

        let capabilities = A2UIClientCapabilities(supportedCatalogIds: ["cat"])
        let prepared = try makeOwnership().outboundMetadata(base, capabilities: capabilities, for: "researcher")

        #expect(A2UIMessageMetadata.clientCapabilities(in: prepared) == capabilities)
        let dataModel = A2UIMessageMetadata.clientDataModel(in: prepared)
        #expect(dataModel?.surfaces.keys.sorted() == ["owned"])
    }

    @Test func stripsToEmptyForAgentWithNoSurfaces() throws {
        // Official interceptor strips even when nothing is kept — never forward foreign data.
        var base: A2AMetadata = [:]
        try A2UIMessageMetadata.embed(A2UIClientDataModel(surfaces: [
            "owned": .object(["a": .int(1)]),
        ]), into: &base)

        let prepared = try makeOwnership().outboundMetadata(base, capabilities: nil, for: "visualizer")
        #expect(A2UIMessageMetadata.clientDataModel(in: prepared)?.surfaces.isEmpty == true)
    }

    @Test func passesThroughWhenNothingToDo() throws {
        let ownership = makeOwnership()
        #expect(try ownership.outboundMetadata(nil, capabilities: nil, for: "researcher") == nil)

        let unrelated: A2AMetadata = ["trace": .string("abc")]
        let prepared = try ownership.outboundMetadata(unrelated, capabilities: nil, for: "researcher")
        #expect(prepared?["trace"]?.stringValue == "abc")
        #expect(A2UIMessageMetadata.clientDataModel(in: prepared) == nil)
    }
}
