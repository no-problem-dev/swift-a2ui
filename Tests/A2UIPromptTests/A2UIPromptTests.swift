import Testing
@testable import A2UIPrompt

// MARK: - WorkflowRules

@Suite("A2UIWorkflowRules")
struct WorkflowRulesTests {
    @Test("default rules contain a2ui-json tag instructions")
    func defaultRulesContainTagInstructions() {
        let rules = A2UIWorkflowRules.default
        #expect(rules.contains("<a2ui-json>"))
        #expect(rules.contains("</a2ui-json>"))
    }

    @Test("default rules mention top-down component ordering")
    func defaultRulesMentionOrdering() {
        #expect(A2UIWorkflowRules.default.contains("Top-Down Component Ordering"))
    }

    @Test("default rules state root component must be first")
    func defaultRulesRootFirst() {
        #expect(A2UIWorkflowRules.default.contains("'root' component MUST be the FIRST element"))
    }
}

// MARK: - SchemaBlockFormatter

@Suite("SchemaBlockFormatter")
struct SchemaBlockFormatterTests {
    @Test("formatted block starts with BEGIN marker")
    func startsWithBeginMarker() {
        let block = SchemaBlockFormatter.format(
            serverToClientSchema: "{}",
            commonTypesSchema: "{}",
            catalogSchema: "{}"
        )
        #expect(block.contains(SchemaBlockFormatter.beginMarker))
    }

    @Test("formatted block ends with END marker")
    func endsWithEndMarker() {
        let block = SchemaBlockFormatter.format(
            serverToClientSchema: "{}",
            commonTypesSchema: "{}",
            catalogSchema: "{}"
        )
        #expect(block.contains(SchemaBlockFormatter.endMarker))
    }

    @Test("formatted block contains all three schema labels")
    func containsAllSchemaLabels() {
        let block = SchemaBlockFormatter.format(
            serverToClientSchema: "S2C",
            commonTypesSchema: "COMMON",
            catalogSchema: "CATALOG"
        )
        #expect(block.contains("### Server To Client Schema: S2C"))
        #expect(block.contains("### Common Types Schema: COMMON"))
        #expect(block.contains("### Catalog Schema: CATALOG"))
    }

    @Test("BEGIN marker appears before END marker")
    func beginBeforeEnd() {
        let block = SchemaBlockFormatter.format(
            serverToClientSchema: "{}",
            commonTypesSchema: "{}",
            catalogSchema: "{}"
        )
        let beginRange = block.range(of: SchemaBlockFormatter.beginMarker)!
        let endRange = block.range(of: SchemaBlockFormatter.endMarker)!
        #expect(beginRange.lowerBound < endRange.lowerBound)
    }
}

// MARK: - A2UIPromptBuilder (custom schemas)

@Suite("A2UIPromptBuilder – custom schemas")
struct A2UIPromptBuilderCustomTests {

    let builder = A2UIPromptBuilder(
        serverToClientSchema: #"{"s2c":true}"#,
        commonTypesSchema: #"{"common":true}"#,
        catalogSchema: #"{"catalog":true}"#
    )

    @Test("prompt starts with the role string")
    func promptStartsWithRole() {
        let role = "You are a UI-generating assistant."
        let prompt = builder.buildSystemPrompt(role: role)
        #expect(prompt.hasPrefix(role))
    }

    @Test("prompt contains workflow section header")
    func promptContainsWorkflowHeader() {
        let prompt = builder.buildSystemPrompt(role: "role")
        #expect(prompt.contains("## Workflow Description:"))
    }

    @Test("prompt contains default workflow rules when none supplied")
    func promptContainsDefaultRules() {
        let prompt = builder.buildSystemPrompt(role: "role")
        #expect(prompt.contains(A2UIWorkflowRules.default))
    }

    @Test("prompt uses custom workflow rules when supplied")
    func promptUsesCustomRules() {
        let custom = "Custom rules go here."
        let prompt = builder.buildSystemPrompt(role: "role", workflowRules: custom)
        #expect(prompt.contains(custom))
        #expect(!prompt.contains(A2UIWorkflowRules.default))
    }

    @Test("prompt omits UI description section when not provided")
    func promptOmitsUISectionByDefault() {
        let prompt = builder.buildSystemPrompt(role: "role")
        #expect(!prompt.contains("## UI Description:"))
    }

    @Test("prompt includes UI description section when provided")
    func promptIncludesUISection() {
        let ui = "Show a card with a title."
        let prompt = builder.buildSystemPrompt(role: "role", uiDescription: ui)
        #expect(prompt.contains("## UI Description:"))
        #expect(prompt.contains(ui))
    }

    @Test("prompt includes schema block by default")
    func promptIncludesSchemaByDefault() {
        let prompt = builder.buildSystemPrompt(role: "role")
        #expect(prompt.contains(SchemaBlockFormatter.beginMarker))
        #expect(prompt.contains(SchemaBlockFormatter.endMarker))
    }

    @Test("prompt omits schema block when includeSchema is false")
    func promptOmitsSchemaWhenDisabled() {
        let prompt = builder.buildSystemPrompt(role: "role", includeSchema: false)
        #expect(!prompt.contains(SchemaBlockFormatter.beginMarker))
    }

    @Test("schema block contains custom schema content")
    func schemaBlockContainsCustomContent() {
        let block = builder.schemaBlock()
        #expect(block.contains(#"{"s2c":true}"#))
        #expect(block.contains(#"{"common":true}"#))
        #expect(block.contains(#"{"catalog":true}"#))
    }

    @Test("full prompt section order: role → workflow → ui → schema")
    func promptSectionOrder() {
        let role = "ROLE"
        let ui = "UI_DESC"
        let prompt = builder.buildSystemPrompt(role: role, uiDescription: ui)

        let roleIdx = prompt.range(of: role)!.lowerBound
        let workflowIdx = prompt.range(of: "## Workflow Description:")!.lowerBound
        let uiIdx = prompt.range(of: "## UI Description:")!.lowerBound
        let schemaIdx = prompt.range(of: SchemaBlockFormatter.beginMarker)!.lowerBound

        #expect(roleIdx < workflowIdx)
        #expect(workflowIdx < uiIdx)
        #expect(uiIdx < schemaIdx)
    }

    @Test("examples are appended in their own section after schema")
    func examplesSection() {
        let examples = "---BEGIN EX1---\n<a2ui-json>{}</a2ui-json>\n---END EX1---"
        let prompt = builder.buildSystemPrompt(role: "role", examples: examples)
        #expect(prompt.contains("### Examples:"))
        #expect(prompt.contains("---BEGIN EX1---"))
        let schemaIdx = prompt.range(of: SchemaBlockFormatter.beginMarker)!.lowerBound
        let examplesIdx = prompt.range(of: "### Examples:")!.lowerBound
        #expect(schemaIdx < examplesIdx)
    }

    @Test("examples section is absent when examples is nil")
    func examplesAbsentWhenNil() {
        let prompt = builder.buildSystemPrompt(role: "role")
        #expect(!prompt.contains("### Examples:"))
    }
}

// MARK: - A2UIPromptBuilder (bundled schemas)

@Suite("A2UIPromptBuilder – bundled schemas")
struct A2UIPromptBuilderBundledTests {

    @Test("schema block is non-empty with bundled resources")
    func schemaBlockIsNonEmpty() {
        let builder = A2UIPromptBuilder()
        let block = builder.schemaBlock()
        #expect(!block.isEmpty)
        #expect(block.contains(SchemaBlockFormatter.beginMarker))
    }

    @Test("bundled server-to-client schema is valid JSON (contains dollar-sign schema key)")
    func bundledS2CSchemaIsValidJSON() {
        let builder = A2UIPromptBuilder()
        let block = builder.schemaBlock()
        // The bundled server_to_client.json is a JSON Schema document
        #expect(block.contains("$schema"))
    }

    @Test("bundled catalog schema references A2UI catalog id")
    func bundledCatalogSchemaReferencesId() {
        let builder = A2UIPromptBuilder()
        let block = builder.schemaBlock()
        #expect(block.contains("a2ui.org"))
    }
}
