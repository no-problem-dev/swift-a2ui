/// 公式 basic カタログの `instructions`（A2UI v1.0）。
///
/// v1.0 で追加された、カタログに直接埋め込む設計ガイドライン。外部の `rules.txt` を置き換える。
/// `Spec/v1_0/catalogs/basic/catalog.json` から**逐語で**転記しており、
/// `GeneratedCatalogFidelityTests` が公式との一致を固定する。
enum BasicCatalogInstructions {
    static let text = """
    For layout, use the Row and Column components to organize other components.

    ## Catalog Guidelines

    1. String Concatenation & Formatting: A2UI does not support binary operators like '+' or formatting symbols. To concatenate strings or dynamically inject data bindings into text, you must use the catalog function `formatString(value)` where the value string contains placeholders formatted as `${expression}`:
       formatString("Hello ${/user/name}")

    2. Strict Hierarchy: You must strictly adhere to the requested component nesting and hierarchy. If the prompt specifies that a component is 'inside' or 'contained in' another component, you MUST place it as a child of that specific component, not as a sibling or in a different container.

    3. Validation Checks: When components support validation checks, specify any custom error messages directly as the 'message' inside the check. Do NOT create separate text-display components to display validation errors.

    ## Examples

    Example 1: Dynamic text form
    ```json
    [
      {
        "version": "v1.0",
        "createSurface": {
          "surfaceId": "main",
          "components": [
            {
              "id": "root",
              "component": "Column",
              "children": ["repField", "valueField"]
            },
            {
              "id": "repField",
              "component": "TextField",
              "label": "Representative",
              "value": {"path": "/form/rep"},
              "placeholder": "Enter name"
            },
            {
              "id": "valueField",
              "component": "TextField",
              "label": "Deal Value",
              "value": {"path": "/form/value"},
              "placeholder": "0.00",
              "variant": "number",
              "checks": [
                {"call": "required"}
              ]
            }
          ],
          "dataModel": {
            "form": {
              "rep": "John Doe",
              "value": 1500.00
            }
          }
        }
      }
    ]
    ```

    Example 2: Dynamic list with templates
    ```json
    [
      {
        "version": "v1.0",
        "createSurface": {
          "surfaceId": "main",
          "components": [
            {
              "id": "root",
              "component": "Card",
              "child": "breedList"
            },
            {
              "id": "breedList",
              "component": "List",
              "children": {
                "path": "/breeds",
                "componentId": "breedTemplate"
              },
              "direction": "horizontal"
            },
            {
              "id": "breedTemplate",
              "component": "Image",
              "url": {"path": "url"}
            }
          ],
          "dataModel": {
            "breeds": [
              {
                "url": "https://example.com/poodle.jpg"
              },
              {
                "url": "https://example.com/lab.jpg"
              }
            ]
          }
        }
      }
    ]
    ```
    """
}
