_Authors_: @ballerina-platform \
_Created_: 2026/03/03 \
_Updated_: 2026/03/03 \
_Edition_: Swan Lake

# Sanitation for OpenAPI specification

This document records the sanitation done on top of the official OpenAPI specification from Azure AI Foundry Models Service.
The OpenAPI specification is obtained from the [Azure REST API Specs](https://github.com/Azure/azure-rest-api-specs/blob/main/specification/ai/data-plane/OpenAI.v1/azure-v1-v1-generated.yaml).
These changes are done in order to improve the overall usability, and as workarounds for some known language limitations.

1. **Extracted only Responses API endpoint from the full specification**:

   - **Original**: Full Azure AI Foundry Models Service spec with all endpoints (batches, chat completion, responses, files, etc.)
   - **Updated**: Only the `/responses` path and its related schemas are retained
   - **Reason**: This connector module only covers the Responses API. Including unrelated endpoints would generate unnecessary code.

2. **Converted nullable type arrays to `nullable: true`**:

   - **Changed Schemas**: Multiple schemas throughout the specification
   - **Original**: `type: ["string", "null"]` (OpenAPI 3.1.x+ style)
   - **Updated**: `type: string` with `nullable: true`
   - **Reason**: Type arrays are not supported in OpenAPI 3.0.0. The `nullable: true` property is the 3.0.0 equivalent for expressing nullable types.

3. **Removed `default: null` properties**:

   - **Changed Schemas**: Multiple schemas including request and response types
   - **Original**: `default: null`
   - **Updated**: Removed the `default` parameter
   - **Reason**: Temporary workaround until the Ballerina OpenAPI tool supports OpenAPI Specification version v3.1.x+.

4. **Converted `const` to `enum`**:

   - **Changed Schemas**: Multiple schemas with constant values
   - **Original**: `const: "value"`
   - **Updated**: `enum: ["value"]`
   - **Reason**: The `const` keyword is not supported in OpenAPI 3.0.0. Using `enum` with a single value achieves the same effect.

5. **Converted `anyOf`/`oneOf` with null types**:

   - **Changed Schemas**: Multiple schemas using `anyOf`/`oneOf` with `{"type": "null"}`
   - **Original**: `anyOf: [{"type": "string"}, {"type": "null"}]`
   - **Updated**: `type: string` with `nullable: true`
   - **Reason**: The `anyOf`/`oneOf` with `{"type": "null"}` pattern for expressing nullable types is not supported in OpenAPI 3.0.0. The `nullable: true` property is used instead.

6. **Removed OpenAPI 3.2.0-specific features**:

   - Removed `pathItems` from components (not supported in 3.0.0)
   - Removed `propertyNames`, `unevaluatedProperties`, and other JSON Schema draft features
   - **Reason**: These keywords are not part of the OpenAPI 3.0.0 specification.

7. **Fixed `exclusiveMinimum`/`exclusiveMaximum` format**:

   - **Original**: Boolean form (OpenAPI 3.1.x+)
   - **Updated**: Numeric form (OpenAPI 3.0.0)
   - **Reason**: OpenAPI 3.0.0 uses numeric values for exclusive boundaries, not boolean flags.

8. **Renamed schemas to Ballerina-friendly type names**:

   - **Changed Schemas**: All schemas whose generated Ballerina type name was not a valid UpperCamelCase identifier.
   - **Original**:
      - Schema keys carrying the `OpenAI.` namespace prefix (e.g. `OpenAI.CreateResponse`, `OpenAI.ConversationParam-2`), which the tool emitted as escaped type names (`OpenAI\.CreateResponse`, `OpenAI\.ConversationParam\-2`).
      - Inline response body and nested object schemas, which the tool auto-named with underscores or a lowercase start (e.g. `inline_response_200`, `inline_response_200_1`, `AzureContentFilterResultsForResponsesAPI_protected_material_code`).
   - **Updated**:
      - Dropped the dot (and any other non-alphanumeric char) from namespaced keys, keeping the prefix (`OpenAI.CreateResponse` → `OpenAICreateResponse`, `OpenAI.ConversationParam-2` → `OpenAIConversationParam2`).
      - Extracted inline schemas into named components with UpperCamelCase names (`inline_response_200` → `InlineResponse200`, `inline_response_200_1` → `InlineResponse2001`, `AzureContentFilterResultsForResponsesAPI_protected_material_code` → `AzureContentFilterResultsForResponsesAPIProtectedMaterialCode`), updating every `$ref`. The `createResponse`, `getResponse`, and `cancelResponse` operations share the identical response shape, so they continue to reference a single `InlineResponse200` type.
   - **Reason**: Ballerina type names must be valid UpperCamelCase identifiers. Dots, hyphens, underscores, and lowercase starts force backslash-escaped or non-idiomatic type names, which hurts the connector's usability.

9. **Made nullable `$ref` response properties actually nullable via `allOf`**:

   - **Changed Schemas**: `InlineResponse200` (and the structurally identical `OpenAIResponse`) — the `error` and `incomplete_details` properties.
   - **Original**: A `$ref` with a sibling `nullable: true`, e.g.

     ```yaml
     error:
       $ref: '#/components/schemas/OpenAIResponseError'
       nullable: true
     ```

   - **Updated**: Moved the `$ref` under an `allOf` so the sibling `nullable: true` is honored:

     ```yaml
     error:
       allOf:
       - $ref: '#/components/schemas/OpenAIResponseError'
       nullable: true
     ```

   - **Reason**: In OpenAPI 3.0.0 a `$ref` overrides any sibling keywords, so the sibling `nullable: true` was ignored and `error`/`incomplete_details` were generated as non-nullable (`OpenAIResponseError`, `OpenAIResponseIncompleteDetails`). Azure returns `"error": null` on any non-failed response and `"incomplete_details": null` unless the response is incomplete, so these required fields must be nullable. Wrapping the `$ref` in `allOf` lets `nullable: true` apply, generating `OpenAIResponseError?` and `OpenAIResponseIncompleteDetails?`.

10. **Fixed the `completed_at` timestamp field type (was `string`, now a number)**:

    - **Changed Schemas**: `InlineResponse200` and the structurally identical `OpenAIResponse` — the
      `completed_at` property.
    - **Original**:

      ```yaml
      completed_at:
        type: string
        format: date-time
        nullable: true
      ```

    - **Updated**:

      ```yaml
      completed_at:
        type: number
        format: unixtime
        nullable: true
        description: |-
          Unix timestamp (in seconds) of when this Response was completed.
            Only present when the status is `completed`.
      ```

    - **Reason**: `completed_at` is a **Unix timestamp in seconds** — a number, not a date-time
      string. The Azure spec wrongly typed it as `type: string`, so the tool generated
      `string? completed_at?`. At runtime Azure returns a number (e.g. `1783589910`), and
      `ballerina/data.jsondata` then fails with
      `"Payload binding failed: incompatible expected type 'string?' for value '1,783,...'"`,
      breaking every Responses call. Changing it to `type: number, format: unixtime` matches the
      official OpenAI Responses spec for this field (and its sibling `created_at`, already a Unix
      timestamp), so the tool now generates `decimal? completed_at?`, which correctly binds the
      numeric value.

11. **Made `jailbreak` and `task_adherence` optional in `AzureContentFilterResultsForResponsesAPI`**:

    - **Changed Schema**: `AzureContentFilterResultsForResponsesAPI` — removed its
      `required: [jailbreak, task_adherence]` list.
    - **Original**:

      ```yaml
      AzureContentFilterResultsForResponsesAPI:
        type: object
        required:
        - jailbreak
        - task_adherence
        properties:
      ```

    - **Updated**:

      ```yaml
      AzureContentFilterResultsForResponsesAPI:
        type: object
        properties:
      ```

    - **Reason**: `jailbreak` and `task_adherence` are newer Azure content-filter detection
      categories that are **not returned by every deployment/region**. The spec marked them
      `required`, so the tool generated non-optional fields; when Azure omits them,
      `ballerina/data.jsondata` fails with
      `"Payload binding failed: required field 'task_adherence' not present in JSON"`, breaking
      every Responses call. Every other category on this object (`sexual`, `hate`, `violence`,
      `self_harm`, `profanity`, `custom_blocklists`, `custom_topics`, `protected_material_text`, …)
      is already optional; making `jailbreak`/`task_adherence` optional too matches how Azure
      actually returns content-filter results (only the configured/returned categories are present).
      The fields become `AzureContentFilterDetectionResult jailbreak?;` and
      `AzureContentFilterDetectionResult task_adherence?;`, which bind whether or not Azure includes
      them.

## OpenAPI cli command

The following command was used to generate the Ballerina client from the OpenAPI specification. The command should be executed from the repository root directory.

```bash
bal openapi -i docs/spec/openapi.yaml --mode client --license docs/license.txt -o ballerina
```
