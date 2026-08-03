_Authors_: @ballerina-platform \
_Created_: 2026/03/03 \
_Updated_: 2026/08/03 \
_Edition_: Swan Lake

# Sanitation for OpenAPI specification

This document records the sanitation done on top of the official OpenAPI specification from Azure AI Foundry Models Service.
The OpenAPI specification is obtained from the [Azure REST API Specs](https://github.com/Azure/azure-rest-api-specs/blob/main/specification/ai/data-plane/OpenAI.v1/azure-v1-v1-generated.yaml).
These changes are done in order to improve the overall usability, and as workarounds for some known language limitations.

1. **Extracted only the Responses API create operation from the full specification**:

   - **Original**: Full Azure AI Foundry Models Service spec with all endpoints (batches, chat completion, responses, files, etc.)
   - **Updated**: Only `POST /responses` and the schemas reachable from it are retained. See item 14 for the
     removal of the remaining Responses operations and the schemas that became unreachable.
   - **Reason**: This connector module only covers creating model responses. Including unrelated endpoints would generate unnecessary code.

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

12. **Removed the redundant `ApiKeyAuth_` security scheme**:

    - **Changed**: The `ApiKeyAuth_` entry under `components.securitySchemes` (an `apiKey` scheme
      named `authorization`) and its corresponding entry in the top-level `security` list.
    - **Original**:

      ```yaml
      security:
      - ApiKeyAuth: []
      - ApiKeyAuth_: []
      - OAuth2Auth:
        - https://cognitiveservices.azure.com/.default
      ```

    - **Updated**:

      ```yaml
      security:
      - ApiKeyAuth: []
      - OAuth2Auth:
        - https://cognitiveservices.azure.com/.default
      ```

    - **Reason**: A list of security requirement objects is an **OR** in OpenAPI 3.0, so the three
      entries are alternatives. The Ballerina OpenAPI tool, however, collapses every `apiKey` scheme
      into a single `ApiKeysConfig` record with all fields **required**, and emits code that sets
      every one of those headers on every request. That turned the alternatives into an AND: users
      authenticating with an API key had to supply an `authorization` value as well, and the client
      then sent a bogus `Authorization` header next to a valid `api-key` header, which Azure can
      reject with a `401`.

      `ApiKeyAuth_` is redundant: it describes a raw token in the `Authorization` header, which is
      the Microsoft Entra ID path already covered by `OAuth2Auth`. The generated
      `ConnectionConfig.auth` field is `http:BearerTokenConfig|ApiKeysConfig`, so removing the
      duplicate scheme loses no capability — API key authentication uses
      `ApiKeysConfig` and Entra ID authentication uses `http:BearerTokenConfig`. After the change
      `ApiKeysConfig` is `record {| string api\-key; |}` and each resource method sets only the
      `api-key` header.

13. **Documented `output_text` as an SDK-only convenience property**:

    - **Changed Schemas**: `InlineResponse200` and the structurally identical `OpenAIResponse` — the
      `output_text` property.
    - **Updated**: Added a `description` explaining that the field is computed client side and is not
      part of the REST payload.
    - **Reason**: `output_text` is not returned by the service. The official OpenAI SDKs synthesize it
      by concatenating the `text` of every `output_text` content part in `output`; it survives in the
      Azure specification only because that document is machine-derived from OpenAI's. Without a
      description the generated field (`string? output_text?;`) looks like an ordinary response field,
      and reading it silently yields nil. The description flows into the generated Ballerina doc
      comment and points users to the `output` array instead.

      The field itself is retained rather than removed, because doing so would be a breaking change to
      the response record and the behaviour has not been confirmed against every Azure deployment.

14. **Reduced the document to `POST /responses` and pruned every unreachable schema**:

    - **Removed paths**: `GET /responses/{response_id}`, `DELETE /responses/{response_id}`,
      `POST /responses/{response_id}/cancel`, and `GET /responses/{response_id}/input_items`.
    - **Removed schemas**: 52 of the 103 component schemas, leaving 51. The document shrank from
      3652 to 1298 lines. The removed set is exactly the set of schemas that no `$ref` chain from
      the retained operation reaches:

      | Group | Count | Examples |
      |-------|-------|----------|
      | Server-sent event schemas for streaming | 36 | `OpenAIResponseStreamEvent`, `OpenAIResponseTextDeltaEvent`, `OpenAIResponseCreatedEvent` |
      | Schemas used only by the removed operations | 4 | `InlineResponse2001`, `OpenAIResponseItemList`, `OpenAIItemResource`, `OpenAIItemResourceType` |
      | Content schemas orphaned by the subtype removal | 11 | `OpenAIInputTextContent`, `OpenAIOutputContent`, `OpenAIAnnotation`, `OpenAIResponseLogProb` |
      | Duplicate of the retained response schema | 1 | `OpenAIResponse` (structurally identical to `InlineResponse200`) |

15. **Removed `default` from the request-body parameters of `OpenAICreateResponse`**:

    - **Changed Schema**: `OpenAICreateResponse` — the `temperature`, `top_p`, `truncation`,
      `parallel_tool_calls` and `store` properties.
    - **Original**:

      ```yaml
      temperature:
        default: 1
        type: number
        nullable: true
      top_p:
        default: 1
        type: number
        nullable: true
      truncation:
        enum: [auto, disabled]
        default: disabled
        type: string
        nullable: true
      parallel_tool_calls:
        default: true
        type: boolean
        nullable: true
      store:
        default: true
        type: boolean
        nullable: true
      ```

    - **Updated**: Removed the `default` line from each of the five properties. The types, enum
      members, `nullable` markers and descriptions are unchanged.

    - **Reason**: `default:` on a non-`required` property makes the Ballerina OpenAPI tool generate
      a required-with-default field (`decimal? temperature = 1;`) rather than an optional one. Such
      a field is always present in the record value, so `jsondata:toJson(payload)`
      (`ballerina/client.bal`) emitted it on every call: `->/responses.post({model: "gpt-5",
      input: "hi"})` went on the wire as `{"model":"gpt-5","input":"hi","temperature":1.0,
      "top_p":1.0,"parallel_tool_calls":true,"store":true,"truncation":"disabled"}`. Azure
      documents `temperature` and `top_p` as **not supported** for reasoning models — *"The
      following are currently unsupported with reasoning models: `temperature`, `top_p`,
      `presence_penalty`, `frequency_penalty`, `logprobs`, `top_logprobs`, `logit_bias`,
      `max_tokens`"*
      ([Azure OpenAI reasoning models](https://learn.microsoft.com/en-us/azure/ai-foundry/openai/how-to/reasoning)) —
      and the strict families reject the *presence* of the key with
      `400 Unsupported parameter: 'temperature' is not supported with this model.` even when the
      value is the default `1`. That made every GPT-5-series and o-series deployment
      uncallable. `parallel_tool_calls` is additionally rejected when no `tools` are present
      (`400 - "'parallel_tool_calls' is only allowed when 'tools' are specified."`). Removing the
      defaults makes the tool generate plain optional fields (`decimal? temperature?;`), which are
      serialized only when the caller sets them. All five are optional upstream with no
      requirement to send them, and the values being sent were the service-side defaults, so
      behaviour for the GPT-4 families is unchanged.

    - **Note**: the identical `default` entries on `InlineResponse200` (`temperature`, `top_p`,
      `truncation`, `parallel_tool_calls`) were deliberately **kept**. That schema is response-only
      and is never serialized onto a request, and the defaults make its data binding tolerant of a
      payload that omits those keys — dropping them would turn `temperature` into a
      required-without-default field, which Ballerina data binding rejects on an absent key even
      when the field type is nilable.

## OpenAPI cli command

The following command was used to generate the Ballerina client from the OpenAPI specification. The command should be executed from the repository root directory.

```bash
bal openapi -i docs/spec/openapi.yaml --mode client --license docs/license.txt -o ballerina
```
