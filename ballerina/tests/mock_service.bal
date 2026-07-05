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

// A mock of the Azure OpenAI Responses endpoints. The request body is bound as
// `map<json>` so the mock accepts any valid `OpenAI.CreateResponse` shape (the
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
        return buildResponse("resp-mock00001", model, "completed", "Mock response generated successfully.");
    }

    // Retrieves a model response with the given ID.
    resource function get responses/[string response_id]() returns json {
        return buildResponse(response_id, "gpt-4o-mini", "completed", "Retrieved mock response.");
    }

    // Deletes a response by ID.
    resource function delete responses/[string response_id]() returns json {
        return {
            "object": "response.deleted",
            "id": response_id,
            "deleted": true
        };
    }

    // Cancels a model response with the given ID.
    resource function post responses/[string response_id]/cancel() returns json {
        return buildResponse(response_id, "gpt-4o-mini", "cancelled", ());
    }

    // Returns a list of input items for a given response.
    resource function get responses/[string response_id]/input_items() returns json {
        return {
            "object": "list",
            "data": [
                {"type": "message"},
                {"type": "reasoning"}
            ],
            "has_more": false,
            "first_id": "msg-0001",
            "last_id": "msg-0002"
        };
    }
};

// Builds a minimal but schema-valid `inline_response_200` payload. `error` and
// `incomplete_details` are returned as `null`, which the relaxed data binding
// treats as absent (they carry no value on a successful response).
isolated function buildResponse(string id, string model, string status, string? outputText) returns json {
    return {
        "id": id,
        "object": "response",
        "created_at": 1723091495,
        "completed_at": null,
        "status": status,
        "model": model,
        "tool_choice": "auto",
        "tools": [],
        "output": [],
        "output_text": outputText,
        "instructions": null,
        "metadata": null,
        // `error` and `incomplete_details` are required (non-nilable) in the
        // generated `inline_response_200` type, so they must always be present.
        "error": {"code": "server_error", "message": ""},
        "incomplete_details": {},
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

function init() returns error? {
    if isLiveServer {
        log:printInfo("Skipping mock server initialization as tests are running on live server");
        return;
    }
    log:printInfo("Initiating mock server...");
    check httpListener.attach(mockService, "/");
    check httpListener.'start();
}
