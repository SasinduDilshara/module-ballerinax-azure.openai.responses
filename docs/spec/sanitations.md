_Authors_: @ballerina-platform \
_Created_: 2026/03/03 \
_Updated_: 2026/03/03 \
_Edition_: Swan Lake

# Sanitation for OpenAPI specification

This document records the sanitation done on top of the official OpenAPI specification from Azure AI Foundry Models Service.
The OpenAPI specification is obtained from the [Azure REST API Specs](https://github.com/Azure/azure-rest-api-specs/blob/main/specification/ai/data-plane/OpenAI.v1/azure-v1-v1-generated.yaml).
These changes are done in order to improve the overall usability, and as workarounds for some known language limitations.

1. **Converted nullable type arrays to `nullable: true`**:

   - **Changed Schemas**: Multiple schemas throughout the specification
   - **Original**: `type: ["string", "null"]` (OpenAPI 3.1.x+ style)
   - **Updated**: `type: string` with `nullable: true`
   - **Reason**: Type arrays are not supported in OpenAPI 3.0.0. The `nullable: true` property is the 3.0.0 equivalent for expressing nullable types.

2. **Removed `default: null` properties**:

   - **Changed Schemas**: Multiple schemas including request and response types
   - **Original**: `default: null`
   - **Updated**: Removed the `default` parameter
   - **Reason**: Temporary workaround until the Ballerina OpenAPI tool supports OpenAPI Specification version v3.1.x+.

3. **Converted `const` to `enum`**:

   - **Changed Schemas**: Multiple schemas with constant values
   - **Original**: `const: "value"`
   - **Updated**: `enum: ["value"]`
   - **Reason**: The `const` keyword is not supported in OpenAPI 3.0.0. Using `enum` with a single value achieves the same effect.

4. **Converted `anyOf`/`oneOf` with null types**:

   - **Changed Schemas**: Multiple schemas using `anyOf`/`oneOf` with `{"type": "null"}`
   - **Original**: `anyOf: [{"type": "string"}, {"type": "null"}]`
   - **Updated**: `type: string` with `nullable: true`
   - **Reason**: The `anyOf`/`oneOf` with `{"type": "null"}` pattern for expressing nullable types is not supported in OpenAPI 3.0.0. The `nullable: true` property is used instead.

5. **Removed OpenAPI 3.2.0-specific features**:

   - Removed `pathItems` from components (not supported in 3.0.0)
   - Removed `propertyNames`, `unevaluatedProperties`, and other JSON Schema draft features
   - **Reason**: These keywords are not part of the OpenAPI 3.0.0 specification.

6. **Fixed `exclusiveMinimum`/`exclusiveMaximum` format**:

   - **Original**: Boolean form (OpenAPI 3.1.x+)
   - **Updated**: Numeric form (OpenAPI 3.0.0)
   - **Reason**: OpenAPI 3.0.0 uses numeric values for exclusive boundaries, not boolean flags.

7. **Made `jailbreak` and `task_adherence` optional in `AzureContentFilterResultsForResponsesAPI`**:

   - **Changed Schema**: `AzureContentFilterResultsForResponsesAPI`
   - **Original**: `jailbreak` and `task_adherence` listed under `required`
   - **Updated**: Removed both fields from the `required` array (fields remain present as optional properties)
   - **Reason**: These fields are not always present in Azure content filter responses. Marking them as required causes deserialization failures when the API omits them.

8. **Made `content_filters` optional in `OpenAI.Response` and inline response schemas**:

   - **Changed Schemas**: Named `OpenAI.Response` component schema and the inline 200 response schemas for `POST /responses`, `GET /responses/{id}`, and `POST /responses/{id}/cancel`
   - **Original**: `content_filters` listed under `required`
   - **Updated**: Removed `content_filters` from the `required` array (field remains present as an optional property)
   - **Reason**: The `content_filters` field is not guaranteed to be present in every response (e.g., when content filtering is not configured or not triggered). Requiring it causes deserialization failures for responses that omit it.

9. **Made `error` and `incomplete_details` optional in `OpenAI.Response` and inline response schemas**:

   - **Changed Schemas**: Named `OpenAI.Response` component schema and the inline 200 response schemas for `POST /responses`, `GET /responses/{id}`, and `POST /responses/{id}/cancel`
   - **Original**: `error` and `incomplete_details` listed under `required`
   - **Updated**: Removed both fields from the `required` array (fields remain present as optional properties)
   - **Reason**: Both fields are `nullable: true` in the spec, meaning the API can return `null` for them. The Ballerina OpenAPI tool maps required+nullable fields as optional (`?`), so the `required` constraint was inconsistent with the generated type and causing a mismatch between the spec and the Ballerina representation.

10. **Removed `tool_choice` from response object schemas**:

    - **Changed Schemas**: Inline 200 response schemas for `POST /responses`, `GET /responses/{id}`, and `POST /responses/{id}/cancel`, and the named `OpenAI.Response` component schema
    - **Original**: Each response schema included `tool_choice: $ref: '#/components/schemas/OpenAI.ToolChoiceParam'`
    - **Updated**: The `tool_choice` property was removed from all four response object schemas
    - **Reason**: `tool_choice` is a request-only parameter (it controls model behaviour during generation). The Responses API does not echo it back in the response body, so including it in response schemas is incorrect and causes the Ballerina code generator to emit a spurious field.

## OpenAPI cli command

The following command was used to generate the Ballerina client from the OpenAPI specification. The command should be executed from the repository root directory.

```bash
bal openapi -i docs/spec/openapi.yaml --mode client --license docs/license.txt -o ballerina
```
Note: The license year is hardcoded to 2026, change if necessary.
