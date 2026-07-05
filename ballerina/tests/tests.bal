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
import ballerina/os;
import ballerina/test;

configurable boolean isLiveServer = os:getEnv("IS_LIVE_SERVER") == "true";
configurable string token = isLiveServer ? os:getEnv("AZURE_OPENAI_TOKEN") : "test";
configurable string apiKey = isLiveServer ? os:getEnv("AZURE_OPENAI_API_KEY") : "test";
configurable string serviceUrl = isLiveServer ? os:getEnv("AZURE_OPENAI_SERVICE_URL") : "http://localhost:9090";

final string mockServiceUrl = "http://localhost:9090";
const AzureAIFoundryModelsApiVersion apiVersion = "v1";

// Client authenticated with a bearer token (default for both mock and live runs).
final Client azureOpenAI = check initClient();

isolated function initClient() returns Client|error {
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

    inline_response_200 response = check azureOpenAI->/responses.post(request, api\-version = apiVersion);
    test:assertTrue(response.id.length() > 0, msg = "Expected a non-empty response ID");
    test:assertEquals(response.'object, "response", msg = "Expected object type to be 'response'");
    test:assertEquals(response.status, "completed");
}

@test:Config {
    groups: ["mock_tests"]
}
isolated function testCreateResponseWithApiKeyAuth() returns error? {
    // Exercises the API key authentication branch of the client initialization.
    // `ApiKeysConfig` requires both the `api-key` and `authorization` fields.
    Client apiKeyClient = check new ({auth: {api\-key: apiKey, authorization: "Bearer " + token}}, mockServiceUrl);

    OpenAI\.CreateResponse request = {
        model: "gpt-4o-mini",
        input: "Ping"
    };

    inline_response_200 response = check apiKeyClient->/responses.post(request);
    test:assertEquals(response.'object, "response");
}

@test:Config {
    groups: ["live_tests", "mock_tests"]
}
isolated function testCreateResponseWithOptionalParams() returns error? {
    OpenAI\.CreateResponse request = {
        model: "gpt-4o-mini",
        input: "Tell me a joke",
        temperature: 0.7,
        top_p: 0.9,
        max_output_tokens: 256,
        store: true,
        instructions: "Be concise."
    };

    inline_response_200 response = check azureOpenAI->/responses.post(request, api\-version = apiVersion);
    test:assertEquals(response.'object, "response");

    OpenAI\.ResponseUsage? usage = response.usage;
    test:assertTrue(usage is OpenAI\.ResponseUsage, msg = "Expected usage statistics");
    if usage is OpenAI\.ResponseUsage {
        test:assertEquals(usage.total_tokens, 18);
    }
}

@test:Config {
    groups: ["mock_tests"]
}
isolated function testCreateResponseWithEmptyModelReturnsError() {
    OpenAI\.CreateResponse request = {
        model: "",
        input: "This should fail"
    };

    inline_response_200|error response = azureOpenAI->/responses.post(request);
    test:assertTrue(response is error, msg = "Expected an error for an empty model");
    if response is http:ClientRequestError {
        test:assertEquals(response.detail().statusCode, 400);
    }
}

@test:Config {
    groups: ["mock_tests"]
}
isolated function testGetResponse() returns error? {
    inline_response_200 response = check azureOpenAI->/responses/["resp-mock00001"].get(api\-version = apiVersion);
    test:assertEquals(response.id, "resp-mock00001");
    test:assertEquals(response.'object, "response");
}

@test:Config {
    groups: ["mock_tests"]
}
isolated function testDeleteResponse() returns error? {
    inline_response_200_1 response = check azureOpenAI->/responses/["resp-mock00001"].delete(api\-version = apiVersion);
    test:assertEquals(response.id, "resp-mock00001");
    test:assertEquals(response.'object, "response.deleted");
    test:assertTrue(response.deleted);
}

@test:Config {
    groups: ["mock_tests"]
}
isolated function testCancelResponse() returns error? {
    inline_response_200 response = check azureOpenAI->/responses/["resp-mock00001"]/cancel.post(api\-version = apiVersion);
    test:assertEquals(response.id, "resp-mock00001");
    test:assertEquals(response.status, "cancelled");
}

@test:Config {
    groups: ["mock_tests"]
}
isolated function testListInputItems() returns error? {
    OpenAI\.ResponseItemList response = check azureOpenAI->/responses/["resp-mock00001"]/input_items.get(api\-version = apiVersion, 'limit = 20);
    test:assertEquals(response.'object, "list");
    test:assertEquals(response.data.length(), 2);
    test:assertFalse(response.has_more);
    test:assertEquals(response.data[0].'type, "message");
}
