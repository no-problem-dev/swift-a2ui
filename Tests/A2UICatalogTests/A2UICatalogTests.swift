import Foundation
import Testing

@testable import A2UICatalog
@testable import A2UICore

// MARK: - Helper

struct ExampleFile: Codable {
    let name: String
    let description: String
    let messages: [ServerMessage]
}

private func decodeComponents(from messages: [ServerMessage]) throws -> [BasicComponent] {
    var components: [BasicComponent] = []
    for message in messages {
        if case .updateComponents(let uc) = message {
            let data = try JSONEncoder().encode(uc.components)
            let decoded = try JSONDecoder().decode([BasicComponent].self, from: data)
            components.append(contentsOf: decoded)
        }
    }
    return components
}

private func loadExample(_ name: String) throws -> ExampleFile {
    guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") else {
        throw A2UITestError.fixtureNotFound(name)
    }
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(ExampleFile.self, from: data)
}

private enum A2UITestError: Error {
    case fixtureNotFound(String)
}

// MARK: - Component Round-Trip

@Suite("Component Round-Trip")
struct ComponentRoundTripTests {

    @Test func textComponent() throws {
        let c = TextComponent(id: "t1", text: "Hello", variant: .h2)
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(TextComponent.self, from: data)
        #expect(decoded.id == "t1")
        #expect(decoded.text == .literal("Hello"))
        #expect(decoded.variant == .h2)
    }

    @Test func imageComponent() throws {
        let c = ImageComponent(id: "img1", url: "https://example.com/img.png", fit: .cover, variant: .largeFeature)
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(ImageComponent.self, from: data)
        #expect(decoded.id == "img1")
        #expect(decoded.fit == .cover)
        #expect(decoded.variant == .largeFeature)
    }

    @Test func iconComponent() throws {
        let c = IconComponent(id: "ic1", name: .preset(.search))
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(IconComponent.self, from: data)
        #expect(decoded.id == "ic1")
        #expect(decoded.name == .preset(.search))
    }

    @Test func videoComponent() throws {
        let c = VideoComponent(id: "v1", url: "https://example.com/video.mp4")
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(VideoComponent.self, from: data)
        #expect(decoded.url == .literal("https://example.com/video.mp4"))
    }

    @Test func audioPlayerComponent() throws {
        let c = AudioPlayerComponent(id: "a1", url: "https://example.com/audio.mp3", description: "My Song")
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(AudioPlayerComponent.self, from: data)
        #expect(decoded.componentDescription == DynamicString.literal("My Song"))
    }

    @Test func rowComponent() throws {
        let c = RowComponent(id: "r1", children: .ids(["a", "b"]), justify: .spaceBetween, align: .center)
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(RowComponent.self, from: data)
        #expect(decoded.children == .ids(["a", "b"]))
        #expect(decoded.justify == .spaceBetween)
    }

    @Test func columnComponent() throws {
        let c = ColumnComponent(id: "c1", children: .ids(["x", "y"]), justify: .start, align: .stretch)
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(ColumnComponent.self, from: data)
        #expect(decoded.children == .ids(["x", "y"]))
    }

    @Test func listComponent() throws {
        let c = ListComponent(id: "l1", children: .template(componentId: "item", path: "/items"), direction: .horizontal)
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(ListComponent.self, from: data)
        #expect(decoded.direction == .horizontal)
    }

    @Test func cardComponent() throws {
        let c = CardComponent(id: "card1", child: "col1")
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(CardComponent.self, from: data)
        #expect(decoded.child == "col1")
    }

    @Test func tabsComponent() throws {
        let c = TabsComponent(id: "tabs1", tabs: [
            TabItem(title: "Tab 1", child: "content1"),
            TabItem(title: "Tab 2", child: "content2"),
        ])
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(TabsComponent.self, from: data)
        #expect(decoded.tabs.count == 2)
        #expect(decoded.tabs[0].title == .literal("Tab 1"))
    }

    @Test func modalComponent() throws {
        let c = ModalComponent(id: "m1", trigger: "btn1", content: "dialog1")
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(ModalComponent.self, from: data)
        #expect(decoded.trigger == "btn1")
        #expect(decoded.content == "dialog1")
    }

    @Test func dividerComponent() throws {
        let c = DividerComponent(id: "d1", axis: .vertical)
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(DividerComponent.self, from: data)
        #expect(decoded.axis == .vertical)
    }

    @Test func buttonComponent() throws {
        let c = ButtonComponent(
            id: "btn1", child: "btn-text",
            action: .event(EventAction(name: "submit")),
            variant: .primary
        )
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(ButtonComponent.self, from: data)
        #expect(decoded.variant == .primary)
    }

    @Test func textFieldComponent() throws {
        let c = TextFieldComponent(
            id: "tf1", label: "Email",
            value: .binding(DataBinding(path: "/email")),
            variant: .shortText
        )
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(TextFieldComponent.self, from: data)
        #expect(decoded.label == .literal("Email"))
        #expect(decoded.variant == .shortText)
    }

    @Test func checkBoxComponent() throws {
        let c = CheckBoxComponent(id: "cb1", label: "Agree", value: .literal(false))
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(CheckBoxComponent.self, from: data)
        #expect(decoded.value == .literal(false))
    }

    @Test func choicePickerComponent() throws {
        let c = ChoicePickerComponent(
            id: "cp1",
            options: [
                ChoiceOption(label: "Red", value: "red"),
                ChoiceOption(label: "Blue", value: "blue"),
            ],
            value: .literal(["red"]),
            variant: .mutuallyExclusive
        )
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(ChoicePickerComponent.self, from: data)
        #expect(decoded.options.count == 2)
        #expect(decoded.variant == .mutuallyExclusive)
    }

    @Test func sliderComponent() throws {
        let c = SliderComponent(id: "s1", value: .literal(50), max: 100, min: 0)
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(SliderComponent.self, from: data)
        #expect(decoded.max == 100)
    }

    @Test func dateTimeInputComponent() throws {
        let c = DateTimeInputComponent(id: "dt1", value: "2025-12-15", enableDate: true)
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(DateTimeInputComponent.self, from: data)
        #expect(decoded.enableDate == true)
    }
}

// MARK: - BasicComponent Discriminated Decode

@Suite("BasicComponent Discriminated Decode")
struct BasicComponentDiscriminatedTests {

    @Test func decodesTextViaDiscriminator() throws {
        let json = #"{"id": "t1", "component": "Text", "text": "Hello", "variant": "h2"}"#
        let decoded = try JSONDecoder().decode(BasicComponent.self, from: Data(json.utf8))
        if case .text(let t) = decoded {
            #expect(t.id == "t1")
            #expect(t.text == .literal("Hello"))
            #expect(t.variant == .h2)
        } else {
            Issue.record("Expected .text case")
        }
    }

    @Test func decodesButtonViaDiscriminator() throws {
        let json = """
        {"id": "btn1", "component": "Button", "child": "btn-text",
         "action": {"event": {"name": "submit"}}, "variant": "primary"}
        """
        let decoded = try JSONDecoder().decode(BasicComponent.self, from: Data(json.utf8))
        if case .button(let b) = decoded {
            #expect(b.id == "btn1")
            #expect(b.variant == .primary)
        } else {
            Issue.record("Expected .button case")
        }
    }

    @Test func decodesDividerMinimal() throws {
        let json = #"{"id": "d1", "component": "Divider"}"#
        let decoded = try JSONDecoder().decode(BasicComponent.self, from: Data(json.utf8))
        if case .divider(let d) = decoded {
            #expect(d.id == "d1")
            #expect(d.axis == nil)
        } else {
            Issue.record("Expected .divider case")
        }
    }

    @Test func rejectsUnknownComponent() {
        let json = #"{"id": "x", "component": "FooBar"}"#
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(BasicComponent.self, from: Data(json.utf8))
        }
    }

    @Test func idAccessor() throws {
        let json = #"{"id": "card1", "component": "Card", "child": "col1"}"#
        let decoded = try JSONDecoder().decode(BasicComponent.self, from: Data(json.utf8))
        #expect(decoded.id == "card1")
        #expect(decoded.componentName == "Card")
    }
}

// MARK: - Official Example Decoding (all 36 examples)

@Suite("Official Example Decoding")
struct OfficialExampleDecodingTests {

    @Test(arguments: [
        "01_flight-status",
        "02_email-compose",
        "03_calendar-day",
        "04_weather-current",
        "05_product-card",
        "06_music-player",
        "07_task-card",
        "08_user-profile",
        "09_login-form",
        "10_notification-permission",
        "11_purchase-complete",
        "12_chat-message",
        "13_coffee-order",
        "14_sports-player",
        "15_account-balance",
        "16_workout-summary",
        "17_event-detail",
        "18_track-list",
        "19_software-purchase",
        "20_restaurant-card",
    ])
    func decodesExample(_ name: String) throws {
        let example = try loadExample(name)
        let components = try decodeComponents(from: example.messages)
        #expect(!components.isEmpty, "Example \(name) should have components")
    }

    @Test(arguments: [
        "21_shipping-status",
        "22_credit-card",
        "23_step-counter",
        "24_recipe-card",
        "25_contact-card",
        "26_podcast-episode",
        "27_stats-card",
        "28_countdown-timer",
        "29_movie-card",
        "30_live-invitation-builder",
        "31_incremental-dashboard",
        "32_advanced-form-validator",
        "33_financial-data-grid",
        "34_child-list-template",
        "35_markdown-text",
        "36_modal",
    ])
    func decodesExampleBatch2(_ name: String) throws {
        let example = try loadExample(name)
        let components = try decodeComponents(from: example.messages)
        #expect(!components.isEmpty, "Example \(name) should have components")
    }

    @Test func flightStatusHasCorrectComponentTypes() throws {
        let example = try loadExample("01_flight-status")
        let components = try decodeComponents(from: example.messages)

        let componentNames = components.map(\.componentName)
        #expect(componentNames.contains("Card"))
        #expect(componentNames.contains("Column"))
        #expect(componentNames.contains("Row"))
        #expect(componentNames.contains("Text"))
        #expect(componentNames.contains("Icon"))
        #expect(componentNames.contains("Divider"))
    }

    @Test func loginFormHasInputComponents() throws {
        let example = try loadExample("09_login-form")
        let components = try decodeComponents(from: example.messages)

        let componentNames = components.map(\.componentName)
        #expect(componentNames.contains("TextField"))
        #expect(componentNames.contains("Button"))
    }

    @Test func childListTemplateHasTemplateChildren() throws {
        let example = try loadExample("34_child-list-template")
        let components = try decodeComponents(from: example.messages)

        let listComponents = components.compactMap { c -> ListComponent? in
            if case .list(let l) = c { return l }
            return nil
        }

        let hasTemplate = listComponents.contains { c in
            if case .template = c.children { return true }
            return false
        }
        #expect(hasTemplate, "Should have at least one List with template children")
    }
}
