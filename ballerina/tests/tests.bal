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

import ballerina/data.jsondata;
import ballerina/http;
import ballerina/os;
import ballerina/test;

configurable boolean isLiveServer = os:getEnv("IS_LIVE_SERVER") == "true";
configurable string token = isLiveServer ? os:getEnv("AZURE_OPENAI_TOKEN") : "test";
configurable string apiKey = isLiveServer ? os:getEnv("AZURE_OPENAI_API_KEY") : "test";
configurable string serviceUrl = isLiveServer ? os:getEnv("AZURE_OPENAI_SERVICE_URL") : "http://localhost:9090";

final string mockServiceUrl = "http://localhost:9090";
const AzureAIFoundryModelsApiVersion apiVersion = "v1";

// Client authenticated with the Azure OpenAI API key, which the connector sends in the
// `api-key` header. This is the authentication method described in the setup guide, so it
// is the default for both mock and live runs.
final Client azureOpenAI = check initClient();

isolated function initClient() returns Client|error {
    if isLiveServer {
        return new ({auth: {api\-key: apiKey}}, serviceUrl);
    }
    return new ({auth: {api\-key: apiKey}}, mockServiceUrl);
}

// Concatenates the text of every `output_text` content part in an `output` array.
//
// The `output_text` field on the response is a convenience property computed by the
// official SDKs; the REST API does not send it, so the generated text has to be read from
// `output`. Content parts are collected regardless of the parent item type, because the
// wire value for an assistant message (`message`) differs from the value listed in the
// `OpenAIOutputItemType` enum generated from the Azure spec (`output_message`).
isolated function extractOutputText(OpenAIOutputItem[] output) returns string {
    string[] texts = [];
    foreach OpenAIOutputItem item in output {
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

@test:Config {
    groups: ["live_tests", "mock_tests"]
}
isolated function testCreateResponse() returns error? {
    OpenAICreateResponse request = {
        model: "gpt-4o-mini",
        input: "This is a test message"
    };

    InlineResponse200 response = check azureOpenAI->/responses.post(request, api\-version = apiVersion);
    test:assertTrue(response.id.length() > 0, msg = "Expected a non-empty response ID");
    test:assertEquals(response.'object, "response", msg = "Expected object type to be 'response'");
    test:assertEquals(response.status, "completed");
}

@test:Config {
    groups: ["mock_tests"]
}
isolated function testCreateResponseWithBearerTokenAuth() returns error? {
    // Exercises the bearer token branch of the client initialization. This header carries a
    // Microsoft Entra ID access token; an Azure OpenAI API key must not be sent this way,
    // because Azure only accepts keys in the `api-key` header.
    Client bearerClient = check new ({auth: {token}}, mockServiceUrl);

    OpenAICreateResponse request = {
        model: "gpt-4o-mini",
        input: "Ping"
    };

    InlineResponse200 response = check bearerClient->/responses.post(request);
    test:assertEquals(response.'object, "response");
}

@test:Config {
    groups: ["live_tests", "mock_tests"]
}
isolated function testResponseTextIsReadFromOutputArray() returns error? {
    OpenAICreateResponse request = {
        model: "gpt-4o-mini",
        input: "This is a test message"
    };

    InlineResponse200 response = check azureOpenAI->/responses.post(request, api\-version = apiVersion);

    // The generated text must be reachable by walking `output`, which is the only
    // representation the REST API actually sends.
    test:assertTrue(response.output.length() > 0, msg = "Expected a non-empty output array");
    test:assertTrue(extractOutputText(response.output).length() > 0,
            msg = "Expected assistant text in the output array");
}

@test:Config {
    groups: ["mock_tests"]
}
isolated function testOutputTextIsNotSentByTheService() returns error? {
    // `output_text` is computed client side by the official SDKs and is absent from the
    // REST payload, so reading it yields nil. Guards the docs and the example against
    // regressing to `response?.output_text`.
    OpenAICreateResponse request = {
        model: "gpt-4o-mini",
        input: "This is a test message"
    };

    InlineResponse200 response = check azureOpenAI->/responses.post(request, api\-version = apiVersion);
    test:assertTrue(response?.output_text is (), msg = "output_text must not be populated from the payload");
    test:assertEquals(extractOutputText(response.output), "Mock response generated successfully.");
}

@test:Config {
    groups: ["live_tests", "mock_tests"]
}
isolated function testNullableRequiredFieldsBind() returns error? {
    OpenAICreateResponse request = {
        model: "gpt-4o-mini",
        input: "This is a test message"
    };

    InlineResponse200 response = check azureOpenAI->/responses.post(request, api\-version = apiVersion);

    // `error` and `incomplete_details` are required but nullable; on a successful
    // (non-failed, complete) response they are null. This exercises the nullable fields.
    test:assertTrue(response.'error is (), "Expected null error on a successful response");
    test:assertTrue(response.incomplete_details is (), "Expected null incomplete_details");
}

@test:Config {
    groups: ["live_tests", "mock_tests"]
}
isolated function testCreateResponseWithOptionalParams() returns error? {
    OpenAICreateResponse request = {
        model: "gpt-4o-mini",
        input: "Tell me a joke",
        temperature: 0.7,
        top_p: 0.9,
        max_output_tokens: 256,
        store: true,
        instructions: "Be concise."
    };

    InlineResponse200 response = check azureOpenAI->/responses.post(request, api\-version = apiVersion);
    test:assertEquals(response.'object, "response");

    OpenAIResponseUsage? usage = response.usage;
    test:assertTrue(usage is OpenAIResponseUsage, msg = "Expected usage statistics");
    if usage is OpenAIResponseUsage {
        test:assertEquals(usage.total_tokens, 18);
    }
}

@test:Config {
    groups: ["mock_tests"]
}
isolated function testCreateResponseWithEmptyModelReturnsError() {
    OpenAICreateResponse request = {
        model: "",
        input: "This should fail"
    };

    InlineResponse200|error response = azureOpenAI->/responses.post(request);
    test:assertTrue(response is error, msg = "Expected an error for an empty model");
    if response is http:ClientRequestError {
        test:assertEquals(response.detail().statusCode, 400);
    }
}

// Guards the sanitation that removed `default:` from the request-body sampling
// parameters. A parameter the caller never set must not appear in the serialised
// body: the reasoning models (o-series, gpt-5 family) reject the *presence* of
// these keys, so a defaulted-but-always-present field made those models
// uncallable. `jsondata:toJson` is the exact serialiser used by `client.bal`.
@test:Config {
    groups: ["mock_tests"]
}
isolated function testUnsetRequestParametersAreNotSerialized() returns error? {
    OpenAICreateResponse request = {
        model: "gpt-5",
        input: "This is a test message"
    };

    map<json> body = check jsondata:toJson(request).ensureType();
    foreach string paramName in ["temperature", "top_p", "truncation", "parallel_tool_calls", "store"] {
        test:assertFalse(body.hasKey(paramName),
                msg = string `Expected '${paramName}' to be omitted when the caller does not set it`);
    }

    // An explicitly set parameter must still be serialised.
    request.temperature = 0.2;
    map<json> bodyWithTemperature = check jsondata:toJson(request).ensureType();
    test:assertEquals(bodyWithTemperature["temperature"], 0.2d,
            msg = "Expected an explicitly set temperature to be sent");
}
