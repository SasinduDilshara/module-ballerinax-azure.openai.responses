# Ballerina Azure OpenAI Responses connector

[![Build](https://github.com/ballerina-platform/module-ballerinax-azure.openai.responses/actions/workflows/ci.yml/badge.svg)](https://github.com/ballerina-platform/module-ballerinax-azure.openai.responses/actions/workflows/ci.yml)
[![GitHub Last Commit](https://img.shields.io/github/last-commit/ballerina-platform/module-ballerinax-azure.openai.responses.svg)](https://github.com/ballerina-platform/module-ballerinax-azure.openai.responses/commits/main)
[![GitHub Issues](https://img.shields.io/github/issues/ballerina-platform/ballerina-library/module/azure.openai.responses.svg?label=Open%20Issues)](https://github.com/ballerina-platform/ballerina-library/labels/module%2Fazure.openai.responses)

## Overview

[Azure OpenAI](https://learn.microsoft.com/en-us/azure/ai-services/openai/) provides access to OpenAI's powerful language models including GPT-4o, GPT-4, and o-series models through Microsoft Azure's enterprise-grade infrastructure. It combines OpenAI's advanced AI capabilities with Azure's security, compliance, and regional availability features.

The `ballerinax/azure.openai.responses` package offers functionality to connect and interact with the [Responses API](https://learn.microsoft.com/en-us/rest/api/aifoundry/) of the Azure AI Foundry Models Service. The Responses API is a stateful API that provides a more powerful and flexible way to build AI applications, supporting features like multi-turn conversations, built-in tools (web search, file search, code interpreter), and background processing.

## Setup guide

To use the Azure OpenAI Responses Connector, you must have access to an Azure OpenAI resource through a [Microsoft Azure account](https://azure.microsoft.com). If you do not have an Azure account, you can sign up for one [here](https://azure.microsoft.com/en-us/free/).

#### Create an Azure OpenAI resource and obtain the API key

1. Sign in to the [Azure Portal](https://portal.azure.com).

2. Search for "Azure OpenAI" in the top search bar and select **Azure OpenAI** from the results.

3. Click **Create** to create a new Azure OpenAI resource. Fill in the required details such as subscription, resource group, region, and resource name, then click **Review + create** and finally **Create**.

4. Once the resource is deployed, navigate to your Azure OpenAI resource.

5. In the left-hand menu, go to **Resource Management** -> **Keys and Endpoint**.

6. Copy one of the provided keys (Key 1 or Key 2) and the endpoint URL. Store them securely to use in your application.

## Quickstart

To use the `Azure OpenAI Responses` connector in your Ballerina application, update the `.bal` file as follows:

### Step 1: Import the module

Import the `ballerinax/azure.openai.responses` module.

```ballerina
import ballerinax/azure.openai.responses;
```

### Step 2: Create a new connector instance

Create a `responses:Client` with the obtained API key and your Azure OpenAI resource endpoint.

```ballerina
configurable string token = ?;
configurable string serviceUrl = ?;

final responses:Client azureOpenAI = check new ({
    auth: {
        token
    }
}, serviceUrl);
```

### Step 3: Invoke the connector operation

Now, you can utilize available connector operations.

#### Create a model response

```ballerina
public function main() returns error? {

    responses:OpenAI\.CreateResponse request = {
        model: "gpt-4o-mini",
        input: "What is the Ballerina programming language?"
    };

    responses:inline_response_200_5 response = check azureOpenAI->/responses.post(request);
    io:println(response.output_text);
}
```

### Step 4: Run the Ballerina application

```bash
bal run
```

## Examples

The `Azure OpenAI Responses` connector provides practical examples illustrating usage in various scenarios. Explore these [examples](https://github.com/ballerina-platform/module-ballerinax-azure.openai.responses/tree/main/examples/), covering the following use cases:

1. [Simple response](https://github.com/ballerina-platform/module-ballerinax-azure.openai.responses/tree/main/examples/simple-response) - Create and retrieve a model response using the Azure OpenAI Responses API.
2. [Background response](https://github.com/ballerina-platform/module-ballerinax-azure.openai.responses/tree/main/examples/background-response) - Run a model response in the background and cancel it when no longer needed.
