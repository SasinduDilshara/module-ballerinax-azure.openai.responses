# Simple Response

This example demonstrates how to create a model response using the Azure OpenAI Responses API.

## Prerequisites

1. Generate an Azure OpenAI API key as described in the [setup guide](https://central.ballerina.io/ballerinax/azure.openai.responses/latest#setup-guide).

2. Create a `Config.toml` file in the `simple-response` directory with the following content:

    ```toml
    apiKey = "<Azure OpenAI API Key>"
    serviceUrl = "https://<resource-name>.openai.azure.com/openai/v1"
    ```

    The API key is sent in the `api-key` header, and the service URL must include the `/openai/v1` base path.

## Run the example

Execute the following commands to build and run the example:

```bash
bal run
```

## What this example does

1. Creates a model response asking the model to explain the Ballerina programming language.
2. Prints the response text, which it reads from the `output_text` content parts of the response's `output` array. The `output_text` field on the response itself is a convenience property computed by the official OpenAI SDKs and is not sent by the REST API.
