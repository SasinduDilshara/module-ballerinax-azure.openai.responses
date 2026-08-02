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

import ballerina/io;
import ballerinax/azure.openai.responses;

// The Azure OpenAI API key. The connector sends it in the `api-key` header.
configurable string apiKey = ?;

// The Responses API base URL, which must include the `/openai/v1` path segment, e.g.
// `https://<resource-name>.openai.azure.com/openai/v1`.
configurable string serviceUrl = ?;

public function main() returns error? {
    final responses:Client azureOpenAI = check new ({
        auth: {
            api\-key: apiKey
        }
    }, serviceUrl);

    // Create a model response
    responses:OpenAICreateResponse request = {
        model: "gpt-4o-mini",
        input: "Explain what the Ballerina programming language is in one sentence."
    };

    responses:InlineResponse200 createResponse = check azureOpenAI->/responses.post(request);
    io:println("Created response ID: " + createResponse.id);
    io:println("Status: " + (createResponse.status ?: "unknown"));
    io:println("Response text: " + extractOutputText(createResponse.output));
}

# Concatenates the text of every `output_text` content part in an `output` array.
#
# The `output_text` field on the response is a convenience property that the official
# OpenAI SDKs compute on the client side. The REST API does not send it, so the generated
# text has to be read from the `output` array instead. Content parts are collected
# regardless of the parent item type, which keeps the helper working for reasoning models
# that emit additional output items alongside the assistant message.
#
# + output - The `output` array of a response
# + return - The concatenated assistant text, or an empty string if there was none
isolated function extractOutputText(responses:OpenAIOutputItem[] output) returns string {
    string[] texts = [];
    foreach responses:OpenAIOutputItem item in output {
        anydata content = item["content"];
        if content !is anydata[] {
            continue;
        }
        foreach anydata part in content {
            if part !is map<anydata> || part["type"] != "output_text" {
                continue;
            }
            anydata text = part["text"];
            if text is string {
                texts.push(text);
            }
        }
    }
    return string:'join("", ...texts);
}
