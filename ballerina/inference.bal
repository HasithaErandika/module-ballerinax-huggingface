// Copyright (c) 2026, Hasitha Erandika (http://github.com/HasithaErandika).
// Licensed under the Apache License, Version 2.0.
// SPDX-License-Identifier: Apache-2.0

import ballerina/data.jsondata;
import ballerina/http;

// ─── Generic Inference ───────────────────────────────────────────────────────

# Performs a generic inference call against any Hugging Face hosted model.
#
# + hfClient - A configured `Client` instance
# + model - The model ID (e.g., `"gpt2"`, `"meta-llama/Llama-3.2-3B-Instruct"`)
# + payload - JSON payload sent to the inference endpoint
# + headers - Optional additional HTTP headers
# + return - The raw JSON response from the model, or an error
public isolated function inferModel(
        Client hfClient,
        string model,
        json payload,
        map<string|string[]> headers = {}) returns json|error {
    string resourcePath = string `/hf-inference/models/${getEncodedUri(model)}`;
    http:Request request = new;
    request.setPayload(jsondata:toJson(payload), "application/json");
    http:Client ep = hfClient.getHttpClient();
    http:Response resp = check ep->post(resourcePath, request, headers);
    if resp.statusCode >= 400 {
        string|error errBody = resp.getTextPayload();
        string details = errBody is string ? errBody : "No error details available.";
        return error(string `Inference request failed with status ${resp.statusCode}: ${details}`);
    }
    return check resp.getJsonPayload();
}

// ─── RAG Helpers ─────────────────────────────────────────────────────────────

# Computes cosine similarity between two float vectors.
#
# + a - First vector (e.g., query embedding)
# + b - Second vector (e.g., document embedding)
# + return - Cosine similarity score between -1.0 and 1.0, or an error for invalid inputs
isolated function cosineSimilarity(float[] a, float[] b) returns float|error {
    if a.length() != b.length() {
        return error(string `Vector length mismatch: a=${a.length()}, b=${b.length()}`);
    }
    if a.length() == 0 {
        return error("Cannot compute cosine similarity of empty vectors.");
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

# Retrieval-Augmented Generation (RAG) pipeline that embeds a query and documents,
# ranks by cosine similarity, and generates a grounded answer from the top-K results.
#
# + hfClient - A configured `Client` instance
# + query - The natural-language question to answer
# + documents - The corpus of documents to search through
# + embeddingModel - Model ID for generating embeddings
# + generationModel - Chat model ID for generating the answer
# + topK - Number of most relevant documents to include as context (must be ≥ 1)
# + return - A `RagResult` containing the answer, source documents, and scores, or an error
public isolated function ragQuery(
        Client hfClient,
        string query,
        RagDocument[] documents,
        string embeddingModel = "intfloat/multilingual-e5-large",
        string generationModel = "katanemo/Arch-Router-1.5B:hf-inference",
        int topK = 3) returns RagResult|error {

    if documents.length() == 0 {
        return error("RAG requires at least one document.");
    }
    if topK < 1 {
        return error("topK must be at least 1.");
    }

    // Step 1 — embed the query
    float[] queryEmbedding = check hfClient->
        /hf\-inference/models/[embeddingModel]/feature\-extraction.post({
            inputs: query
        });

    // Step 2 — embed each document and compute similarity
    float[] scores = [];
    foreach RagDocument doc in documents {
        float[] docEmbedding = check hfClient->
            /hf\-inference/models/[embeddingModel]/feature\-extraction.post({
                inputs: doc.content
            });
        float similarity = check cosineSimilarity(queryEmbedding, docEmbedding);
        scores.push(similarity);
    }

    // Step 3 — select top-K documents by descending score
    int k = int:min(topK, documents.length());
    int[] indices = from int i in 0 ..< scores.length()
        order by scores[i] descending
        limit k
        select i;

    RagDocument[] topDocs = [];
    float[] topScores = [];
    foreach int idx in indices {
        topDocs.push(documents[idx]);
        topScores.push(scores[idx]);
    }

    // Step 4 — build context from the top documents
    string context = "";
    foreach int i in 0 ..< topDocs.length() {
        context += string `[Document ${i + 1}]: ${topDocs[i].content}\n\n`;
    }

    // Step 5 — generate a grounded answer
    string prompt = string `Answer the following question using only the provided context.
If the answer is not in the context, say "I don't know."

Context:
${context}
Question: ${query}
Answer:`;

    ChatCompletionResponse genResult = check hfClient->
        /v1/chat/completions.post({
            model: generationModel,
            messages: [{role: "user", content: prompt}],
            maxTokens: 200
        });

    string answer = "";
    ChatCompletionChoice[]? choices = genResult?.choices;
    if choices is ChatCompletionChoice[] && choices.length() > 0 {
        ChatMessage? msg = choices[0].message;
        if msg is ChatMessage {
            answer = msg.content;
        }
    }

    return {answer, sources: topDocs, scores: topScores};
}