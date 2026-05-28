import Testing
@testable import A2UISurface
import A2UICore

@Suite("EventSource")
struct EventSourceTests {

    @Test("emit reaches all subscribers; cancel detaches")
    func emitAndCancel() {
        let src = EventSource<Int>()
        final class Box: @unchecked Sendable { var values: [Int] = [] }
        let a = Box(); let b = Box()
        let subA = src.subscribe { a.values.append($0) }
        let subB = src.subscribe { b.values.append($0) }
        src.emit(1)
        subA.cancel()
        src.emit(2)
        #expect(a.values == [1])
        #expect(b.values == [1, 2])
        subB.cancel()
    }

    @Test("does not replay past events to late subscribers")
    func noReplay() {
        let src = EventSource<String>()
        src.emit("early")
        final class Box: @unchecked Sendable { var values: [String] = [] }
        let box = Box()
        let sub = src.subscribe { box.values.append($0) }
        #expect(box.values.isEmpty)
        src.emit("late")
        #expect(box.values == ["late"])
        sub.cancel()
    }
}

@Suite("SurfaceComponentsModel lifecycle")
struct SurfaceComponentsModelTests {

    @Test("apply creates a component and emits onCreated")
    func applyCreates() {
        let model = SurfaceComponentsModel()
        final class Box: @unchecked Sendable { var created: [String] = [] }
        let box = Box()
        let sub = model.onCreated.subscribe { box.created.append($0.id) }
        model.apply(.object(["id": .string("btn"), "component": .string("Button"), "label": .string("Go")]))
        #expect(model.get("btn")?.type == "Button")
        #expect(model.get("btn")?.properties["label"] == .string("Go"))
        #expect(box.created == ["btn"])
        sub.cancel()
    }

    @Test("same id + same type updates properties in place (identity preserved)")
    func sameTypeUpdatesInPlace() {
        let model = SurfaceComponentsModel()
        model.apply(.object(["id": .string("t"), "component": .string("Text"), "text": .string("A")]))
        let first = model.get("t")
        model.apply(.object(["id": .string("t"), "component": .string("Text"), "text": .string("B")]))
        let second = model.get("t")
        #expect(first === second)  // same instance
        #expect(second?.properties["text"] == .string("B"))
    }

    @Test("same id + different type recreates (spec lifecycle rule)")
    func differentTypeRecreates() {
        let model = SurfaceComponentsModel()
        final class Box: @unchecked Sendable { var deleted: [String] = []; var created: [String] = [] }
        let box = Box()
        let d = model.onDeleted.subscribe { box.deleted.append($0) }
        let c = model.onCreated.subscribe { box.created.append($0.id) }
        model.apply(.object(["id": .string("x"), "component": .string("Text")]))
        let first = model.get("x")
        model.apply(.object(["id": .string("x"), "component": .string("Button")]))
        let second = model.get("x")
        #expect(first !== second)  // fresh instance
        #expect(second?.type == "Button")
        #expect(box.deleted == ["x"])
        #expect(box.created == ["x", "x"])
        d.cancel(); c.cancel()
    }
}

@MainActor
@Suite("MessageProcessor")
struct MessageProcessorTests {

    @Test("create → updateComponents → updateDataModel → delete")
    func fullLifecycle() throws {
        let mp = MessageProcessor()
        try mp.process(.createSurface(CreateSurface(surfaceId: "s1", catalogId: "cat", theme: nil, sendDataModel: true)))
        #expect(mp.surface(id: "s1")?.sendDataModel == true)

        try mp.process(.updateComponents(UpdateComponents(surfaceId: "s1", components: [
            .object(["id": .string("root"), "component": .string("Column"), "children": .array([.string("t")])]),
            .object(["id": .string("t"), "component": .string("Text"), "text": .string("Hi")]),
        ])))
        #expect(mp.surface(id: "s1")?.components.get("root") != nil)
        #expect(mp.surface(id: "s1")?.components.get("t")?.type == "Text")

        try mp.process(.updateDataModel(UpdateDataModel(surfaceId: "s1", path: "/score", value: .int(10))))
        #expect(mp.surface(id: "s1")?.dataModel.get("/score") == .int(10))

        try mp.process(.deleteSurface(DeleteSurface(surfaceId: "s1")))
        #expect(mp.surface(id: "s1") == nil)
    }

    @Test("duplicate createSurface throws surfaceAlreadyExists")
    func duplicateCreate() throws {
        let mp = MessageProcessor()
        try mp.process(.createSurface(CreateSurface(surfaceId: "s1", catalogId: "c")))
        #expect(throws: MessageProcessor.ProcessError.surfaceAlreadyExists("s1")) {
            try mp.process(.createSurface(CreateSurface(surfaceId: "s1", catalogId: "c")))
        }
    }

    @Test("updateComponents on missing surface throws surfaceNotFound")
    func missingSurface() {
        let mp = MessageProcessor()
        #expect(throws: MessageProcessor.ProcessError.surfaceNotFound("ghost")) {
            try mp.process(.updateComponents(UpdateComponents(surfaceId: "ghost", components: [])))
        }
    }

    @Test("onSurfaceCreated / onSurfaceDeleted fire")
    func lifecycleEvents() throws {
        let mp = MessageProcessor()
        final class Box: @unchecked Sendable { var created: [String] = []; var deleted: [String] = [] }
        let box = Box()
        let c = mp.onSurfaceCreated.subscribe { box.created.append($0.id) }
        let d = mp.onSurfaceDeleted.subscribe { box.deleted.append($0) }
        try mp.process(.createSurface(CreateSurface(surfaceId: "s1", catalogId: "c")))
        try mp.process(.deleteSurface(DeleteSurface(surfaceId: "s1")))
        #expect(box.created == ["s1"])
        #expect(box.deleted == ["s1"])
        c.cancel(); d.cancel()
    }

    @Test("getClientDataModel aggregates only sendDataModel surfaces")
    func clientDataModelAggregation() throws {
        let mp = MessageProcessor()
        try mp.process(.createSurface(CreateSurface(surfaceId: "send", catalogId: "c", theme: nil, sendDataModel: true)))
        try mp.process(.createSurface(CreateSurface(surfaceId: "nosend", catalogId: "c", theme: nil, sendDataModel: false)))
        try mp.process(.updateDataModel(UpdateDataModel(surfaceId: "send", path: "/x", value: .int(1))))
        try mp.process(.updateDataModel(UpdateDataModel(surfaceId: "nosend", path: "/y", value: .int(2))))

        let cdm = mp.getClientDataModel()
        #expect(cdm["send"] == .object(["x": .int(1)]))
        #expect(cdm["nosend"] == nil)
    }

    @Test("action dispatched from surface bubbles to processor.onAction")
    func actionBubbles() throws {
        let mp = MessageProcessor()
        final class Box: @unchecked Sendable { var actions: [String] = [] }
        let box = Box()
        let sub = mp.onAction.subscribe { box.actions.append($0.name) }
        try mp.process(.createSurface(CreateSurface(surfaceId: "s1", catalogId: "c")))
        mp.surface(id: "s1")?.dispatchAction(name: "submit", sourceComponentId: "btn", context: [:])
        #expect(box.actions == ["submit"])
        sub.cancel()
    }

    @Test("updateDataModel full replace when path omitted")
    func fullReplace() throws {
        let mp = MessageProcessor()
        try mp.process(.createSurface(CreateSurface(surfaceId: "s1", catalogId: "c")))
        try mp.process(.updateDataModel(UpdateDataModel(surfaceId: "s1", path: nil, value: .object(["a": .int(1)]))))
        #expect(mp.surface(id: "s1")?.dataModel.snapshot == .object(["a": .int(1)]))
    }
}
