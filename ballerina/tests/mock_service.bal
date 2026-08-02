// Copyright (c) 2026, WSO2 LLC. (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/http;
import ballerina/log;

listener http:Listener httpListener = new (9090);

// A mock of the Azure OpenAI Responses endpoint. The request body is bound as
// `map<json>` so the mock accepts any valid `OpenAICreateResponse` shape (the
// `input` field can be a plain string or an array of input items) without
// re-implementing the union data binding on the server side.
http:Service mockService = service object {

    // Creates a model response.
    resource function post responses(@http:Payload map<json> payload) returns json|http:BadRequest {
        // `model` is optional in the schema, but when supplied it must be a
        // non-empty string. This lets the tests exercise the error path.
        json modelField = payload["model"];
        if modelField is string && modelField.trim() == "" {
            return <http:BadRequest>{body: {"error": {"code": "invalid_request", "message": "model must not be empty"}}};
        }
        string model = modelField is string ? modelField : "gpt-4o-mini";
        return buildResponse("resp-mock00001", model, "Mock response generated successfully.");
    }
};

// Builds a minimal but schema-valid `InlineResponse200` payload. `error` and
// `incomplete_details` are required but nullable, so a successful response
// returns them as `null` (matching Azure's real behaviour).
//
// Note that `output_text` is deliberately absent from the payload: it is a
// convenience property that the official SDKs compute on the client side, and the
// REST API never sends it. The generated text is carried by the `output` array.
isolated function buildResponse(string id, string model, string outputText) returns json {
    return {
        "id": id,
        "object": "response",
        "created_at": 1723091495,
        "completed_at": null,
        "status": "completed",
        "model": model,
        "tool_choice": "auto",
        "tools": [],
        "output": buildOutput(outputText),
        "instructions": null,
        "metadata": null,
        // `error` and `incomplete_details` are required but nullable; a successful
        // response carries them as `null`.
        "error": null,
        "incomplete_details": null,
        "usage": {
            "input_tokens": 10,
            "input_tokens_details": {"cached_tokens": 0},
            "output_tokens": 8,
            "output_tokens_details": {"reasoning_tokens": 0},
            "total_tokens": 18
        },
        "parallel_tool_calls": true,
        "content_filters": []
    };
}

// Builds the `output` array in the shape the Responses API actually returns: a list of
// output items, where an assistant message carries its text in `content` entries of type
// `output_text`. A `reasoning` item is included ahead of the message so the tests cover
// skipping over output items that hold no text content.
isolated function buildOutput(string outputText) returns json[] {
    return [
        {
            "id": "rs-mock00001",
            "type": "reasoning",
            "summary": []
        },
        {
            "id": "msg-mock00001",
            // The wire value for an assistant message is `message`. The `OpenAIOutputItemType`
            // enum generated from the Azure spec lists the TypeSpec-internal `output_message`
            // instead, which is why consumers should not key off the item type alone.
            "type": "message",
            "status": "completed",
            "role": "assistant",
            "content": [
                {
                    "type": "output_text",
                    "text": outputText,
                    "annotations": []
                }
            ]
        }
    ];
}

function init() returns error? {
    if isLiveServer {
        log:printInfo("Skipping mock server initialization as tests are running on live server");
        return;
    }
    log:printInfo("Initiating mock server...");
    check httpListener.attach(mockService, "/");
    check httpListener.'start();
}
