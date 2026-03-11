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

import ballerina/os;
import ballerina/test;

configurable boolean isLiveServer = os:getEnv("IS_LIVE_SERVER") == "true";
configurable string token = isLiveServer ? os:getEnv("AZURE_OPENAI_TOKEN") : "test";
configurable string serviceUrl = isLiveServer ? os:getEnv("AZURE_OPENAI_SERVICE_URL") : "http://localhost:9090";
final string mockServiceUrl = "http://localhost:9090";
final Client azureOpenAI = check initClient();

function initClient() returns Client|error {
    if isLiveServer {
        return new ({auth: {token}}, serviceUrl);
    }
    return new ({auth: {token}}, mockServiceUrl);
}

@test:Config {
    groups: ["live_tests", "mock_tests"]
}
isolated function testCreateResponse() returns error? {
    OpenAI\.CreateResponse request = {
        model: "gpt-4o-mini",
        input: "This is a test message"
    };
    inline_response_200_5 response = check azureOpenAI->/responses.post(request);
    test:assertTrue(response.id.length() > 0, msg = "Expected a non-empty response ID");
    test:assertEquals(response.'object, "response", msg = "Expected object type to be 'response'");
}

