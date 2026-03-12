// Copyright (c) 2026, Hasitha Erandika (http://github.com/HasithaErandika).
// Licensed under the Apache License, Version 2.0.

// Helper utilities for working with the Hugging Face Inference API.
//
// These helpers simplify calling the `/hf-inference/models/{model}` inference endpoints
// for any model (beyond the typed examples generated from OpenAPI).

import ballerina/data.jsondata;
import ballerina/http;

# Perform a generic inference call against a Hugging Face model.
#
# This helper is useful when the model/endpoint does not match one of the
# strongly-typed operations in the generated client API.
#
# + hfClient - A configured `Client` instance (e.g., `check new ({auth: {token}})`)
# + model - The model ID (e.g. "gpt2", "openai-community/gpt2", "meta-llama/Llama-3.2-3B-Instruct")
# + payload - JSON payload sent to the inference endpoint
# + task - Optional task hint (reserved for future use; currently unused in URL routing)
# + headers - Optional headers to send (e.g. for additional Hugging Face options)
# + return - The raw JSON response from the inference endpoint or an error
public isolated function inferModel(Client hfClient, string model, json payload, string task = "", map<string|string[]> headers = {}) returns json|error {
    string resourcePath = string `/hf-inference/models/${getEncodedUri(model)}`;
    http:Request request = new;
    request.setPayload(jsondata:toJson(payload), "application/json");
    http:Client ep = hfClient.clientEp;
    http:Response resp = check ep->post(resourcePath, request, headers);
    json response = check resp.getJsonPayload();
    return response;
}