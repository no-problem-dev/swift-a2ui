import StructuredDataCore
import A2UICore
import AGUICore
import Foundation

/// A client's declaration that it can render A2UI (a `RunAgentInput.context` entry).
///
/// The upstream a2ui-middleware contract puts the declaration in a context entry whose
/// `description` matches exactly — not in capabilities, not in tool metadata. `value` is
/// `{catalogId}` (or `{catalogId, components}`) serialized as a JSON string.
///
/// **Send the catalogId alone by default.** A2UI's own `supportedCatalogIds` is an array of
/// string IDs; shipping component schemas belongs to `inlineCatalogs`, an optional path usable
/// only when the agent advertises `acceptsInlineCatalogs`. The ID is the key that pins the
/// contents, so bump the catalog version whenever the contents change.
public enum A2UISchemaContext {
    /// Client side: builds the declaration entry.
    ///
    /// - Parameters:
    ///   - catalogId: ID of the catalog the client can render.
    ///   - components: Component schemas of the catalog (JSON value). **Omitting it is the
    ///     default** (send the ID alone); attach the contents only when the server does not
    ///     know that catalog.
    ///   - marker: The `description` marking this context entry as a declaration.
    ///     **Defaults to the upstream middleware constant**, discriminated on a byte-exact match.
    ///
    ///     `context` is a general-purpose array, so this string is the only thing that tells a
    ///     declaration from anything else. If you own the other end and get to choose the value,
    ///     use a shorter one — there is no need to send 137 characters on every run.
    ///     **The sender and the reader must use the same value.**
    public static func declaration(
        catalogId: String,
        components: StructuredValue? = nil,
        marker: String = A2UIAGUIConstants.schemaContextDescription
    ) throws -> AGUIContext {
        var object: OrderedObject = ["catalogId": .string(catalogId)]
        if let components {
            object["components"] = components
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return AGUIContext(
            description: marker,
            value: String(decoding: try encoder.encode(StructuredValue.object(object)), as: UTF8.self)
        )
    }

    /// Server side: finds the A2UI declaration in a context list and pulls out its catalogId.
    ///
    /// Whether `components` is present is not considered: as in the upstream middleware's
    /// `extractFrontendCatalogId`, resolving the catalog ID is independent of the schemas.
    public static func declaredCatalogId(
        in context: [AGUIContext],
        marker: String = A2UIAGUIConstants.schemaContextDescription
    ) -> String? {
        guard let entry = declaration(in: context, marker: marker),
              let data = entry.value.data(using: .utf8),
              let value = try? JSONDecoder().decode(StructuredValue.self, from: data) else {
            return nil
        }
        let catalogId = value.objectValue?["catalogId"]?.stringValue
        return (catalogId?.isEmpty ?? true) ? nil : catalogId
    }

    /// Server side: the A2UI declaration entry itself — the first entry whose description is an
    /// exact match for `marker`.
    public static func declaration(
        in context: [AGUIContext],
        marker: String = A2UIAGUIConstants.schemaContextDescription
    ) -> AGUIContext? {
        context.first { $0.description == marker }
    }

    /// A parsed catalog declaration (`{catalogId}` or `{catalogId, components}`).
    public struct Declaration: Sendable, Equatable {
        /// ID of the catalog the client can render.
        public let catalogId: String
        /// The declared components map (component name → JSON Schema).
        /// **`nil` is the default** — an ID-only declaration, whose contents the catalog version
        /// determines.
        public let components: StructuredValue?

        /// The set of declared component names.
        ///
        /// **`nil` means "no narrowing was requested"**, which is not the same as an empty set
        /// ("can render nothing"). An ID-only declaration yields `nil`, and the receiver then
        /// uses every component it knows of that catalog.
        public var componentNames: Set<String>? {
            guard let object = components?.objectValue else {
                return nil
            }
            return Set(object.keys)
        }

        public init(catalogId: String, components: StructuredValue? = nil) {
            self.catalogId = catalogId
            self.components = components
        }
    }

    /// Server side: returns **every** declaration in the context, in order of appearance.
    ///
    /// A client appends one entry per supported catalog, and that order is the preference order
    /// (this is the AG-UI transport form of A2UI's own `supportedCatalogIds` handshake). The
    /// server picks the first declaration whose catalogId it knows. The upstream a2ui-middleware
    /// single-entry contract is the one-element case of this.
    ///
    /// **`components` is optional.** Without it the entry still passes, as an ID-only declaration
    /// whose contents the catalog version determines. Only a declaration with an empty catalogId
    /// is dropped, as "cannot render anything".
    ///
    /// A `components` that is an **empty object** is dropped too — it states "can render nothing"
    /// explicitly, which is distinct from an ID-only declaration (no narrowing requested).
    public static func declarations(
        in context: [AGUIContext],
        marker: String = A2UIAGUIConstants.schemaContextDescription
    ) -> [Declaration] {
        context.compactMap { entry in
            guard entry.description == marker,
                  let data = entry.value.data(using: .utf8),
                  let value = try? JSONDecoder().decode(StructuredValue.self, from: data),
                  let object = value.objectValue,
                  let catalogId = object["catalogId"]?.stringValue,
                  !catalogId.isEmpty else {
                return nil
            }
            guard let components = object["components"] else {
                // ID-only declaration: the default shape.
                return Declaration(catalogId: catalogId)
            }
            guard let map = components.objectValue, !map.isEmpty else {
                // Drop a declaration that explicitly says it can render nothing.
                return nil
            }
            return Declaration(catalogId: catalogId, components: components)
        }
    }
}

/// Definition of the rendering tool injected into the agent (server side).
///
/// `catalogId` is deliberately **not** a parameter — choosing the catalog is the host's
/// authority, so a sub-agent cannot invent a catalog that was never registered.
public enum A2UIRenderTool {
    public static func definition() -> AGUITool {
        AGUITool(
            name: A2UIAGUIConstants.renderToolName,
            description: "Render a dynamic A2UI \(A2UIVersion.current) surface with structured parameters. "
                + "Follow the A2UI render tool usage guide provided in context.",
            parameters: .object([
                "type": .string("object"),
                "properties": .object([
                    "surfaceId": .object([
                        "type": .string("string"),
                        "description": .string("Unique surface identifier."),
                    ]),
                    "components": .object([
                        "type": .string("array"),
                        "items": .object(["type": .string("object")]),
                        "description": .string(
                            "A2UI \(A2UIVersion.current) component array (flat format). The root component must have id \"root\"."
                        ),
                    ]),
                    "data": .object([
                        "type": .string("object"),
                        "description": .string("Initial data model for the surface. Written to the root path."),
                    ]),
                ]),
                "required": .array([.string("surfaceId"), .string("components")]),
            ])
        )
    }
}
