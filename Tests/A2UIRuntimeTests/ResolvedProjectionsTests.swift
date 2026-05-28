import Testing
@testable import A2UIRuntime
import A2UISurface
import A2UICatalog
import A2UICore

@MainActor
@Suite("Typed projections")
struct ResolvedProjectionsTests {

    private func make(
        type: String,
        _ properties: [String: AnyCodable],
        data: AnyCodable = .object([:]),
        scope: String = ""
    ) -> (ResolvedComponent, DataModel) {
        let dm = DataModel(data)
        let fns = BasicFunctions()
        let ctx = ComponentContext(
            componentId: "c",
            componentType: type,
            properties: properties,
            dataContext: DataContext(dataModel: dm, path: scope, functions: fns)
        )
        return (ResolvedComponent(context: ctx, functions: fns), dm)
    }

    @Test("ResolvedText: text + variant decoded into TextVariant")
    func resolvedText() {
        let (r, _) = make(type: "Text", ["text": .string("Hello"), "variant": .string("h2")])
        let p: ResolvedText = r.projected()
        #expect(p.text == "Hello")
        #expect(p.variant == .h2)
        #expect(p.isTextPresent == true)
    }

    @Test("ResolvedText: missing text gives isTextPresent=false (placeholder cue)")
    func resolvedTextPlaceholder() {
        let (r, _) = make(type: "Text", ["text": .string("")])
        let p = r.projected(as: ResolvedText.self)
        #expect(p.isTextPresent == false)
    }

    @Test("ResolvedImage: enums + URL")
    func resolvedImage() {
        let (r, _) = make(type: "Image", [
            "url": .string("https://example.com/x.png"),
            "fit": .string("cover"),
            "variant": .string("avatar"),
            "description": .string("alt"),
        ])
        let p: ResolvedImage = r.projected()
        #expect(p.url == "https://example.com/x.png")
        #expect(p.fit == .cover)
        #expect(p.variant == .avatar)
        #expect(p.description == "alt")
    }

    @Test("ResolvedButton: variant + isEnabled (no checks → enabled)")
    func resolvedButton() {
        let (r, _) = make(type: "Button", [
            "child": .string("lbl"),
            "variant": .string("primary"),
            "action": .object(["event": .object(["name": .string("submit")])]),
        ])
        let p: ResolvedButton = r.projected()
        #expect(p.variant == .primary)
        #expect(p.isEnabled == true)
        #expect(p.child?.componentId == "lbl")
    }

    @Test("ResolvedButton.perform dispatches the event action with resolved context")
    func resolvedButtonPerform() {
        let dm = DataModel(.object(["formId": .string("f-1")]))
        let fns = BasicFunctions()
        final class Box: @unchecked Sendable { var name: String?; var ctx: [String: AnyCodable]? }
        let box = Box()
        let ctx = ComponentContext(
            componentId: "btn", componentType: "Button",
            properties: [
                "child": .string("lbl"),
                "action": .object([
                    "event": .object([
                        "name": .string("submit"),
                        "context": .object(["id": .object(["path": .string("/formId")])]),
                    ])
                ]),
            ],
            dataContext: DataContext(dataModel: dm, functions: fns),
            dispatch: { name, c in box.name = name; box.ctx = c }
        )
        let r = ResolvedComponent(context: ctx, functions: fns)
        let p = r.projected(as: ResolvedButton.self)
        p.perform()
        #expect(box.name == "submit")
        #expect(box.ctx?["id"] == .string("f-1"))
    }

    @Test("ResolvedTextField: Writable.set writes through binding path (with scope)")
    func resolvedTextField() {
        let (r, dm) = make(
            type: "TextField",
            ["label": .string("Email"), "value": .object(["path": .string("email")])],
            data: .object(["users": .array([.object(["email": .string("")])])]),
            scope: "/users/0"
        )
        let p: ResolvedTextField = r.projected()
        #expect(p.label == "Email")
        #expect(p.value.value == "")
        p.value.set("jane@example.com")
        #expect(dm.get("/users/0/email") == .string("jane@example.com"))
    }

    @Test("ResolvedCheckBox: Writable<Bool>")
    func resolvedCheckBox() {
        let (r, dm) = make(
            type: "CheckBox",
            ["label": .string("Accept"), "value": .object(["path": .string("/terms")])],
            data: .object(["terms": .bool(false)])
        )
        let p: ResolvedCheckBox = r.projected()
        #expect(p.value.value == false)
        p.value.set(true)
        #expect(dm.get("/terms") == .bool(true))
    }

    @Test("ResolvedSlider: min/max/value")
    func resolvedSlider() {
        let (r, _) = make(type: "Slider", [
            "min": .double(0), "max": .double(10),
            "value": .object(["path": .string("/v")]),
        ], data: .object(["v": .double(3)]))
        let p: ResolvedSlider = r.projected()
        #expect(p.min == 0)
        #expect(p.max == 10)
        #expect(p.value.value == 3)
    }

    @Test("ResolvedColumn: children + layout enums")
    func resolvedColumn() {
        let (r, _) = make(type: "Column", [
            "children": .array([.string("a"), .string("b")]),
            "justify": .string("spaceBetween"),
            "align": .string("center"),
        ])
        let p: ResolvedColumn = r.projected()
        #expect(p.children.count == 2)
        #expect(p.justify == .spaceBetween)
        #expect(p.align == .center)
    }

    @Test("ResolvedTabs: titles paired with child slots")
    func resolvedTabs() {
        let (r, _) = make(type: "Tabs", [
            "tabs": .array([
                .object(["title": .string("One"), "child": .string("t1")]),
                .object(["title": .string("Two"), "child": .string("t2")]),
            ]),
        ])
        let p: ResolvedTabs = r.projected()
        #expect(p.tabs.count == 2)
        #expect(p.tabs[0].title == "One")
        #expect(p.tabs[0].child.componentId == "t1")
        #expect(p.tabs[1].title == "Two")
    }

    @Test("ResolvedChoicePicker: options decoded, selection binding writes array")
    func resolvedChoicePicker() {
        let (r, dm) = make(type: "ChoicePicker", [
            "options": .array([
                .object(["label": .string("A"), "value": .string("a")]),
                .object(["label": .string("B"), "value": .string("b")]),
            ]),
            "value": .object(["path": .string("/sel")]),
        ], data: .object(["sel": .array([.string("a")])]))
        let p: ResolvedChoicePicker = r.projected()
        #expect(p.options.map(\.value) == ["a", "b"])
        #expect(p.selection.value == ["a"])
        p.selection.set(["b"])
        #expect(dm.get("/sel") == .array([.string("b")]))
    }
}
