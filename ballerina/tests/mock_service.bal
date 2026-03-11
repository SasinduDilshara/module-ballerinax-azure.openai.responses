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

http:Service mockService = service object {

    resource function post responses(@http:Payload OpenAI\.CreateResponse payload) returns json|http:BadRequest {
        if payload.model is () {
            return http:BAD_REQUEST;
        }
        return {
            "id": "resp-mock00001",
            "object": "response",
            "created_at": 1723091495,
            "completed_at": 1723091500,
            "status": "completed",
            "model": payload.model,
            "output": [],
            "output_text": "Mock response generated successfully.",
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

};

function init() returns error? {
    if isLiveServer {
        log:printInfo("Skipping mock server initialization as tests are running on live server");
        return;
    }
    log:printInfo("Initiating mock server...");
    check httpListener.attach(mockService, "/");
    check httpListener.'start();
}
