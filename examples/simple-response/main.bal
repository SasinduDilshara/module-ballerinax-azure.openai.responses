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

configurable string token = ?;
configurable string serviceUrl = ?;

public function main() returns error? {
    final responses:Client azureOpenAI = check new ({
        auth: {
            token
        }
    }, serviceUrl);

    // Create a model response
    responses:OpenAI\.CreateResponse request = {
        model: "gpt-4o-mini",
        input: "Explain what the Ballerina programming language is in one sentence."
    };

    responses:inline_response_200_5 createResponse = check azureOpenAI->/responses.post(request);
    io:println("Created response ID: " + createResponse.id);
    io:println("Status: " + (createResponse.status ?: "unknown"));

    string? outputText = createResponse.output_text;
    if outputText is string {
        io:println("Response text: " + outputText);
    }
}
