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

    // Create a background response - useful for long-running tasks
    responses:OpenAI\.CreateResponse request = {
        model: "o3",
        input: "Write a comprehensive analysis of the history of programming languages from 1950 to the present.",
        background: true
    };

    responses:inline_response_200_5 createResponse = check azureOpenAI->/responses.post(request);
    string responseId = createResponse.id;
    io:println("Background response created with ID: " + responseId);
    io:println("Status: " + (createResponse.status ?: "unknown"));

    // Cancel the background response since we don't need to wait for it
    responses:inline_response_200_5 cancelledResponse = check azureOpenAI->/responses/[responseId]/cancel.post();
    io:println("Response cancelled. New status: " + (cancelledResponse.status ?: "unknown"));

    // Clean up: delete the response
    responses:inline_response_200_6 deleteResponse = check azureOpenAI->/responses/[responseId].delete();
    io:println("Response deleted: " + deleteResponse.deleted.toString());
}
