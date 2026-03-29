// Copyright (c) 2026, Hasitha Erandika (http://github.com/HasithaErandika).
// Licensed under the Apache License, Version 2.0.
// SPDX-License-Identifier: Apache-2.0

import ballerina/data.jsondata;
import ballerina/http;

// ─── Generic Inference ───────────────────────────────────────────────────────

# Perform a generic inference call against any Hugging Face model.
#
# Useful when the model or endpoint does not match one of the strongly-typed
# operations in the generated client. The task is determined automatically
# by the model — no suffix needed in the URL.
#
# + hfClient - A configured `Client` instance
# + model - The model ID (e.g. `"gpt2"`, `"meta-llama/Llama-3.2-3B-Instruct"`)
# + payload - JSON payload sent to the inference endpoint
# + headers - Optional additional HTTP headers
# + return - The raw JSON response or an error
public isolated function inferModel(
        Client hfClient,
        string model,
        json payload,
        map<string|string[]> headers = {}) returns json|error {
    string resourcePath = string `/hf-inference/models/${getEncodedUri(model)}`;
    http:Request request = new;
    request.setPayload(jsondata:toJson(payload), "application/json");
    foreach [string, string|string[]] [name, value] in headers.entries() {
        if value is string {
            request.setHeader(name, value);
        } else {
            foreach string v in value {
                request.addHeader(name, v);
            }
        }
    }
    http:Client ep = hfClient.clientEp;
    http:Response resp = check ep->post(resourcePath, request);
    if resp.statusCode >= 400 {
        string|error errBody = resp.getTextPayload();
        string details = errBody is string ? errBody : "No error details available.";
        return error(string `Inference request failed with status ${resp.statusCode}: ${details}`);
    }
    return check resp.getJsonPayload();
}

// ─── Batch Inference ──────────────────────────────────────────────────────────

# Perform batch inference on multiple inputs in a single API call.
#
# More efficient than calling inferModel repeatedly when processing
# large numbers of inputs against the same model.
#
# + hfClient - A configured `Client` instance
# + model - The model ID
# + inputs - Array of input strings to process in one request
# + headers - Optional additional headers
# + return - Array of JSON results one per input, or an error
public isolated function batchInfer(
        Client hfClient,
        string[] inputs,
        string model,
        map<string|string[]> headers = {}) returns json[]|error {
    string resourcePath = string `/hf-inference/models/${getEncodedUri(model)}`;
    http:Request request = new;
    request.setPayload({"inputs": inputs}.toJson(), "application/json");
    http:Client ep = hfClient.clientEp;
    http:Response resp = check ep->post(resourcePath, request, headers);
    if resp.statusCode >= 400 {
        string|error errBody = resp.getTextPayload();
        string details = errBody is string ? errBody : "No error details available.";
        return error(string `Batch inference request failed with status ${resp.statusCode}: ${details}`);
    }
    json body = check resp.getJsonPayload();
    json[] results = check body.fromJsonWithType();
    return results;
}

// ─── Model Metadata ───────────────────────────────────────────────────────────

# Retrieve metadata for a model from the Hugging Face Hub API.
#
# + hfClient - A configured `Client` instance
# + model - The model ID (e.g. "gpt2", "facebook/bart-large-cnn")
# + return - A ModelInfo record with model details, or an error
public isolated function getModelInfo(
        Client hfClient,
        string model) returns ModelInfo|error {
    http:Client hubClient = check new ("https://huggingface.co");
    http:Response resp = check hubClient->get(string `/api/models/${model}`);
    if resp.statusCode >= 400 {
        string|error errBody = resp.getTextPayload();
        string details = errBody is string ? errBody : "No details available.";
        string reason = resp.statusCode == 404
            ? string `Model '${model}' not found on Hugging Face Hub.`
            : string `Hub API request failed with status ${resp.statusCode}: ${details}`;
        return error(reason);
    }
    json body = check resp.getJsonPayload();
    ModelInfo result = check body.fromJsonWithType();
    return result;
}

# Check whether a model is available on the Hugging Face Inference API.
#
# Returns a ModelAvailability record with availability status and metadata.
# Does not throw an error if the model is not found — returns available: false.
#
# + hfClient - A configured `Client` instance
# + model - The model ID to check
# + return - A ModelAvailability record, or an error if the Hub API fails
public isolated function checkModelAvailability(
        Client hfClient,
        string model) returns ModelAvailability|error {
    ModelInfo|error info = getModelInfo(hfClient, model);
    if info is error {
        return {
            modelId: model,
            available: false,
            pipelineTag: (),
            downloads: ()
        };
    }
    string[]? tags = info.tags;
    boolean available = false;
    if tags is string[] {
        foreach string tag in tags {
            if tag == "inference-api" || tag == "inference" || tag.includes("endpoints_compatible") {
                available = true;
                break;
            }
        }
    }
    return {
        modelId: model,
        available: available,
        pipelineTag: info.pipelineTag,
        downloads: info.downloads
    };
}

// ─── RAG Helpers ─────────────────────────────────────────────────────────────

# Compute cosine similarity between two float vectors.
#
# + a - First embedding vector
# + b - Second embedding vector
# + return - Cosine similarity score between -1.0 and 1.0
isolated function cosineSimilarity(float[] a, float[] b) returns float {
    if a.length() != b.length() || a.length() == 0 {
        return 0.0;
    }
    float dotProduct = 0.0;
    float normA = 0.0;
    float normB = 0.0;
    foreach int i in 0 ..< a.length() {
        dotProduct += a[i] * b[i];
        normA += a[i] * a[i];
        normB += b[i] * b[i];
    }
    float denominator = float:sqrt(normA) * float:sqrt(normB);
    if denominator == 0.0 {
        return 0.0;
    }
    return dotProduct / denominator;
}

// ─── RAG Pipeline ────────────────────────────────────────────────────────────

# Retrieval Augmented Generation (RAG) pipeline.
#
# Embeds the query and all documents, ranks documents by cosine similarity,
# filters by similarity threshold, then generates a grounded answer using
# the top-K documents as context. Uses batch embedding for efficiency.
#
# ### Basic usage
# ```ballerina
# huggingface:RagDocument[] docs = [
#     {id: "1", content: "Ballerina is created by WSO2."},
#     {id: "2", content: "Python is used for data science."}
# ];
# huggingface:RagResult result = check huggingface:ragQuery(hfClient, "Who made Ballerina?", docs);
# io:println(result.answer);
# ```
#
# + hfClient - A configured `Client` instance
# + query - The natural language question to answer
# + documents - The corpus of documents to search through
# + config - RAG configuration (models, topK, threshold, system prompt)
# + return - A RagResult with the answer, source documents, and scores, or an error
public isolated function ragQuery(
        Client hfClient,
        string query,
        RagDocument[] documents,
        RagConfig config = {}) returns RagResult|error {

    if documents.length() == 0 {
        return error("RAG requires at least one document.");
    }

    // collect all texts to embed (query + all documents)
    string[] allTexts = [query];
    foreach RagDocument doc in documents {
        allTexts.push(doc.content);
    }

    // batch embed everything in one API call for efficiency
    float[][] allEmbeddings = check hfClient->
        /hf\-inference/models/[config.embeddingModel]/feature\-extraction/batch.post({inputs: allTexts});

    if allEmbeddings.length() < 1 + documents.length() {
        return error("Embedding batch returned fewer results than expected.");
    }

    float[] queryEmbedding = allEmbeddings[0];

    // compute similarity scores for each document
    float[] scores = [];
    foreach int i in 0 ..< documents.length() {
        float similarity = cosineSimilarity(queryEmbedding, allEmbeddings[i + 1]);
        scores.push(similarity);
    }

    // filter by threshold and select top-K
    int k = int:min(config.topK, documents.length());
    int[] indices = from int i in 0 ..< scores.length()
        where scores[i] >= config.similarityThreshold
        order by scores[i] descending
        limit k
        select i;

    if indices.length() == 0 {
        return {
            answer: "No documents met the similarity threshold for this query.",
            sources: [],
            scores: []
        };
    }

    RagDocument[] topDocs = [];
    float[] topScores = [];
    foreach int idx in indices {
        topDocs.push(documents[idx]);
        topScores.push(scores[idx]);
    }

    // build context from top documents
    string context = "";
    foreach int i in 0 ..< topDocs.length() {
        context += string `[Document ${i + 1}]: ${topDocs[i].content}\n\n`;
    }

    // build messages array with optional system prompt
    ChatMessage[] messages = [];
    if config.systemPrompt.length() > 0 {
        messages.push({role: "system", content: config.systemPrompt});
    } else {
        messages.push({
            role: "system",
            content: "You are a helpful assistant. Answer questions using only the provided context. If the answer is not in the context, say \"I don't know.\""
        });
    }

    string userPrompt = string `Context:\n${context}\nQuestion: ${query}\n\nAnswer:`;
    messages.push({role: "user", content: userPrompt});

    // generate grounded answer
    ChatCompletionResponse genResult = check hfClient->
        /v1/chat/completions.post({
            model: config.generationModel,
            messages: messages,
            maxTokens: config.maxTokens
        });

    string answer = "I don't know.";
    ChatCompletionChoice[]? choices = genResult?.choices;
    if choices is ChatCompletionChoice[] && choices.length() > 0 {
        ChatMessage? msg = choices[0].message;
        if msg is ChatMessage {
            answer = msg.content;
        }
    }

    return {answer, sources: topDocs, scores: topScores};
}