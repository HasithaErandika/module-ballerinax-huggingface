// Copyright (c) 2026, Hasitha Erandika (http://github.com/HasithaErandika).
// Licensed under the Apache License, Version 2.0.
// SPDX-License-Identifier: Apache-2.0

import ballerina/data.jsondata;
import ballerina/http;
import ballerina/io;
import ballerina/lang.runtime;
import ballerina/log;
import ballerina/regex;

# Client for the Hugging Face Inference API.
#
# Provides type-safe access to Hugging Face hosted models including chat completion,
# text generation, classification, embeddings, image generation, speech recognition,
# and more. Supports automatic retries for cold-starting models.
#
# ```ballerina
# huggingface:Client hf = check new ({auth: {token: "<HF_TOKEN>"}});
# ChatCompletionResponse resp = check hf->/v1/chat/completions.post({
#     model: "meta-llama/Llama-3.2-3B-Instruct",
#     messages: [{role: "user", content: "Hello!"}]
# });
# ```
public isolated client class Client {
    final http:Client clientEp;
    final readonly & RetryConfig retryConfig;

    # Initializes the Hugging Face Inference API client.
    #
    # + config - Connection configuration including authentication credentials
    # + serviceUrl - Base URL of the Hugging Face Inference API
    # + retryConfig - Retry settings for handling cold-starting models (HTTP 503)
    # + return - An error if client initialization fails
    public isolated function init(
            ConnectionConfig config,
            string serviceUrl = "https://router.huggingface.co",
            RetryConfig retryConfig = {}) returns error? {
        http:ClientConfiguration httpClientConfig = {
            auth: config.auth,
            httpVersion: config.httpVersion,
            http1Settings: config.http1Settings,
            http2Settings: config.http2Settings,
            timeout: config.timeout,
            forwarded: config.forwarded,
            followRedirects: config.followRedirects,
            poolConfig: config.poolConfig,
            cache: config.cache,
            compression: config.compression,
            circuitBreaker: config.circuitBreaker,
            retryConfig: config.retryConfig,
            cookieConfig: config.cookieConfig,
            responseLimits: config.responseLimits,
            secureSocket: config.secureSocket,
            proxy: config.proxy,
            socketConfig: config.socketConfig,
            validation: config.validation,
            laxDataBinding: config.laxDataBinding
        };
        self.clientEp = check new (serviceUrl, httpClientConfig);
        self.retryConfig = retryConfig.cloneReadOnly();
    }

    # Returns the underlying HTTP client endpoint (package-private).
    #
    # + return - The configured HTTP client
    isolated function getHttpClient() returns http:Client {
        return self.clientEp;
    }

    // ─── Internal Helpers ────────────────────────────────────────────────────

    # Executes an HTTP POST with automatic retry on HTTP 503 (model loading).
    #
    # + resourcePath - The resource path to POST to
    # + request - The HTTP request to send
    # + return - HTTP response or an error if max retries exceeded
    isolated function postWithRetry(
            string resourcePath,
            http:Request request) returns http:Response|error {
        int attempts = 0;
        decimal delay = self.retryConfig.initialDelay;
        while attempts <= self.retryConfig.maxRetries {
            http:Response|error response = self.clientEp->post(resourcePath, request);
            if response is error {
                return response;
            }
            if response.statusCode == 503 && attempts < self.retryConfig.maxRetries {
                attempts += 1;
                log:printInfo(string `Model loading, retrying in ${delay}s ` +
                    string `(attempt ${attempts}/${self.retryConfig.maxRetries})...`);
                runtime:sleep(delay);
                delay = decimal:min(delay * 2.0d, self.retryConfig.maxDelay);
                continue;
            }
            return response;
        }
        return error("Max retries exceeded waiting for model to load.");
    }

    # Sets custom headers on an HTTP request from the provided header map.
    #
    # + request - The HTTP request to add headers to
    # + headers - Map of header names to their values
    isolated function setHeaders(http:Request request, map<string|string[]> headers) {
        foreach [string, string|string[]] [name, value] in headers.entries() {
            if value is string {
                request.setHeader(name, value);
            } else {
                foreach string v in value {
                    request.addHeader(name, v);
                }
            }
        }
    }

    # Validates an HTTP response and extracts the JSON payload, returning a descriptive error for non-2xx responses.
    #
    # + resp - The HTTP response to validate
    # + return - The JSON payload or an error with API error details
    isolated function handleJsonResponse(http:Response resp) returns json|error {
        if resp.statusCode >= 400 {
            string|error errBody = resp.getTextPayload();
            string details = errBody is string ? errBody : "No error details available.";
            return error(string `API request failed with status ${resp.statusCode}: ${details}`);
        }
        return check resp.getJsonPayload();
    }

    // ─── Chat Completion ─────────────────────────────────────────────────────

    # Generates a chat completion using a conversational model.
    #
    # + payload - Chat completion request body containing messages and model ID
    # + headers - Optional HTTP headers to include in the request
    # + return - A `ChatCompletionResponse` with the generated reply, or an error
    resource isolated function post v1/chat/completions(
            ChatCompletionRequest payload,
            map<string|string[]> headers = {}) returns ChatCompletionResponse|error {
        string resourcePath = string `/v1/chat/completions`;
        http:Request request = new;
        self.setHeaders(request, headers);
        request.setPayload(jsondata:toJson(payload), "application/json");
        http:Response resp = check self.postWithRetry(resourcePath, request);
        json body = check self.handleJsonResponse(resp);
        return check body.fromJsonWithType();
    }

    # Streaming Chat Completion — returns chunks of tokens as they are generated.
    #
    # + payload - Chat completion request body
    # + headers - Optional HTTP headers to include in the request
    # + return - A stream of `ChatCompletionChunk` records, or an error
    resource isolated function post v1/chat/completions/streamed(
            ChatCompletionRequest payload,
            map<string|string[]> headers = {}) returns stream<ChatCompletionChunk, error?>|error {
        string resourcePath = string `/v1/chat/completions`;
        http:Request request = new;
        self.setHeaders(request, headers);
        map<json> payloadMap = <map<json>>jsondata:toJson(payload);
        payloadMap["stream"] = true;
        request.setPayload(payloadMap.toJson(), "application/json");
        http:Response resp = check self.clientEp->post(resourcePath, request);
        if resp.statusCode != 200 {
            string|error errBody = resp.getTextPayload();
            string details = errBody is string ? errBody : "No error details available.";
            return error(string `Streaming failed with status ${resp.statusCode}: ${details}`);
        }
        string rawStream = check resp.getTextPayload();
        ChatCompletionChunk[] chunks = [];
        string[] lines = regex:split(rawStream, "\n");
        foreach string line in lines {
            string trimmed = line.trim();
            if trimmed.startsWith("data: ") {
                string data = trimmed.substring(6);
                if data == "[DONE]" {
                    break;
                }
                json|error parsed = data.fromJsonString();
                if parsed is json {
                    ChatCompletionChunk|error chunk = parsed.cloneWithType(ChatCompletionChunk);
                    if chunk is ChatCompletionChunk {
                        chunks.push(chunk);
                    }
                }
            }
        }
        return chunks.toStream();
    }

    // ─── Text Generation ─────────────────────────────────────────────────────

    # Generates text from a prompt using a language model.
    #
    # + model - The model ID (e.g., `"gpt2"`, `"bigscience/bloom"`)
    # + payload - Text generation request body with the prompt and parameters
    # + headers - Optional HTTP headers to include in the request
    # + return - An array of `TextGenerationResult`, or an error
    resource isolated function post hf\-inference/models/[string model](
            TextGenerationRequest payload,
            map<string|string[]> headers = {}) returns TextGenerationResult[]|error {
        string resourcePath = string `/hf-inference/models/${getEncodedUri(model)}`;
        http:Request request = new;
        self.setHeaders(request, headers);
        request.setPayload(jsondata:toJson(payload), "application/json");
        http:Response resp = check self.postWithRetry(resourcePath, request);
        json body = check self.handleJsonResponse(resp);
        return check body.fromJsonWithType();
    }

    // ─── Text Classification ─────────────────────────────────────────────────

    # Classifies text into predefined categories (e.g., sentiment analysis).
    #
    # + model - The model ID (e.g., `"distilbert-base-uncased-finetuned-sst-2-english"`)
    # + payload - Text classification request body
    # + headers - Optional HTTP headers to include in the request
    # + return - A nested array of `ClassificationLabel` results, or an error
    resource isolated function post hf\-inference/models/[string model]/text\-classification(
            TextClassificationRequest payload,
            map<string|string[]> headers = {}) returns ClassificationLabel[][]|error {
        string resourcePath = string `/hf-inference/models/${getEncodedUri(model)}`;
        http:Request request = new;
        self.setHeaders(request, headers);
        request.setPayload(jsondata:toJson(payload), "application/json");
        http:Response resp = check self.postWithRetry(resourcePath, request);
        json body = check self.handleJsonResponse(resp);
        return check body.fromJsonWithType();
    }

    // ─── Token Classification ─────────────────────────────────────────────────

    # Performs token-level classification such as Named Entity Recognition (NER).
    #
    # + model - The model ID (e.g., `"dslim/bert-base-NER"`)
    # + payload - Token classification request body
    # + headers - Optional HTTP headers to include in the request
    # + return - An array of `TokenClassificationEntity` records, or an error
    resource isolated function post hf\-inference/models/[string model]/token\-classification(
            TokenClassificationRequest payload,
            map<string|string[]> headers = {}) returns TokenClassificationEntity[]|error {
        string resourcePath = string `/hf-inference/models/${getEncodedUri(model)}`;
        http:Request request = new;
        self.setHeaders(request, headers);
        request.setPayload(jsondata:toJson(payload), "application/json");
        http:Response resp = check self.postWithRetry(resourcePath, request);
        json body = check self.handleJsonResponse(resp);
        return check body.fromJsonWithType();
    }

    // ─── Feature Extraction ───────────────────────────────────────────────────

    # Extracts feature embeddings from text using an embedding model.
    #
    # + model - The model ID (e.g., `"intfloat/multilingual-e5-large"`)
    # + payload - Feature extraction request body
    # + headers - Optional HTTP headers to include in the request
    # + return - A float array representing the embedding vector, or an error
    resource isolated function post hf\-inference/models/[string model]/feature\-extraction(
            FeatureExtractionRequest payload,
            map<string|string[]> headers = {}) returns float[]|error {
        string resourcePath = string `/hf-inference/models/${getEncodedUri(model)}`;
        http:Request request = new;
        self.setHeaders(request, headers);
        request.setPayload(jsondata:toJson(payload), "application/json");
        http:Response resp = check self.postWithRetry(resourcePath, request);
        json body = check self.handleJsonResponse(resp);
        return check body.fromJsonWithType();
    }

    // ─── Text to Image ────────────────────────────────────────────────────────

    # Generates an image from a text prompt using a diffusion model.
    #
    # + model - The model ID (e.g., `"stabilityai/stable-diffusion-xl-base-1.0"`)
    # + payload - Text-to-image request body with prompt and optional parameters
    # + headers - Optional HTTP headers to include in the request
    # + return - Raw image bytes (typically PNG), or an error
    resource isolated function post hf\-inference/models/[string model]/text\-to\-image(
            TextToImageRequest payload,
            map<string|string[]> headers = {}) returns byte[]|error {
        string resourcePath = string `/hf-inference/models/${getEncodedUri(model)}`;
        http:Request request = new;
        self.setHeaders(request, headers);
        request.setPayload(jsondata:toJson(payload), "application/json");
        http:Response resp = check self.postWithRetry(resourcePath, request);
        if resp.statusCode >= 400 {
            string|error errBody = resp.getTextPayload();
            string details = errBody is string ? errBody : "No error details available.";
            return error(string `API request failed with status ${resp.statusCode}: ${details}`);
        }
        return check resp.getBinaryPayload();
    }

    // ─── Question Answering ───────────────────────────────────────────────────

    # Extracts an answer from a context paragraph given a question.
    #
    # + model - The model ID (e.g., `"deepset/roberta-base-squad2"`)
    # + payload - Question answering request body with question and context
    # + headers - Optional HTTP headers to include in the request
    # + return - A `QuestionAnsweringResponse` with the extracted answer, or an error
    resource isolated function post hf\-inference/models/[string model]/question\-answering(
            QuestionAnsweringRequest payload,
            map<string|string[]> headers = {}) returns QuestionAnsweringResponse|error {
        string resourcePath = string `/hf-inference/models/${getEncodedUri(model)}`;
        http:Request request = new;
        self.setHeaders(request, headers);
        request.setPayload(jsondata:toJson(payload), "application/json");
        http:Response resp = check self.postWithRetry(resourcePath, request);
        json body = check self.handleJsonResponse(resp);
        return check body.fromJsonWithType();
    }

    // ─── Summarization ────────────────────────────────────────────────────────

    # Generates a summary of the given text.
    #
    # + model - The model ID (e.g., `"facebook/bart-large-cnn"`)
    # + payload - Summarization request body with text and optional length parameters
    # + headers - Optional HTTP headers to include in the request
    # + return - An array of `SummarizationResult` records, or an error
    resource isolated function post hf\-inference/models/[string model]/summarization(
            SummarizationRequest payload,
            map<string|string[]> headers = {}) returns SummarizationResult[]|error {
        string resourcePath = string `/hf-inference/models/${getEncodedUri(model)}`;
        http:Request request = new;
        self.setHeaders(request, headers);
        request.setPayload(jsondata:toJson(payload), "application/json");
        http:Response resp = check self.postWithRetry(resourcePath, request);
        json body = check self.handleJsonResponse(resp);
        return check body.fromJsonWithType();
    }

    // ─── Translation ──────────────────────────────────────────────────────────

    # Translates text from one language to another.
    #
    # + model - The model ID (e.g., `"Helsinki-NLP/opus-mt-en-fr"`)
    # + payload - Translation request body
    # + headers - Optional HTTP headers to include in the request
    # + return - An array of `TranslationResult` records, or an error
    resource isolated function post hf\-inference/models/[string model]/translation(
            TranslationRequest payload,
            map<string|string[]> headers = {}) returns TranslationResult[]|error {
        string resourcePath = string `/hf-inference/models/${getEncodedUri(model)}`;
        http:Request request = new;
        self.setHeaders(request, headers);
        request.setPayload(jsondata:toJson(payload), "application/json");
        http:Response resp = check self.postWithRetry(resourcePath, request);
        json body = check self.handleJsonResponse(resp);
        return check body.fromJsonWithType();
    }

    // ─── Zero-Shot Classification ─────────────────────────────────────────────

    # Classifies text against a set of candidate labels without prior training.
    #
    # + model - The model ID (e.g., `"facebook/bart-large-mnli"`)
    # + payload - Zero-shot classification request body with candidate labels
    # + headers - Optional HTTP headers to include in the request
    # + return - A `ZeroShotClassificationResponse` with scores per label, or an error
    resource isolated function post hf\-inference/models/[string model]/zero\-shot\-classification(
            ZeroShotClassificationRequest payload,
            map<string|string[]> headers = {}) returns ZeroShotClassificationResponse|error {
        string resourcePath = string `/hf-inference/models/${getEncodedUri(model)}`;
        http:Request request = new;
        self.setHeaders(request, headers);
        request.setPayload(jsondata:toJson(payload), "application/json");
        http:Response resp = check self.postWithRetry(resourcePath, request);
        json body = check self.handleJsonResponse(resp);
        return check body.fromJsonWithType();
    }

    // ─── Image Classification ─────────────────────────────────────────────────

    # Classifies an image provided as raw bytes.
    #
    # + model - The model ID (e.g., `"google/vit-base-patch16-224"`)
    # + payload - Raw image bytes (JPEG, PNG, etc.)
    # + contentType - Image MIME type (default: `image/jpeg`)
    # + headers - Optional HTTP headers to include in the request
    # + return - An array of `ImageClassificationResult` records, or an error
    resource isolated function post hf\-inference/models/[string model]/image\-classification(
            byte[] payload,
            string contentType = IMAGE_JPEG,
            map<string|string[]> headers = {}) returns ImageClassificationResult[]|error {
        string resourcePath = string `/hf-inference/models/${getEncodedUri(model)}`;
        http:Request request = new;
        self.setHeaders(request, headers);
        request.setPayload(payload, contentType);
        http:Response resp = check self.postWithRetry(resourcePath, request);
        json body = check self.handleJsonResponse(resp);
        return check body.fromJsonWithType();
    }

    # Classifies an image loaded from a local file path.
    #
    # + model - The model ID (e.g., `"google/vit-base-patch16-224"`)
    # + filePath - Absolute or relative path to the image file
    # + contentType - Image MIME type (default: `image/jpeg`)
    # + headers - Optional HTTP headers to include in the request
    # + return - An array of `ImageClassificationResult` records, or an error
    resource isolated function post hf\-inference/models/[string model]/image\-classification/file(
            string filePath,
            string contentType = IMAGE_JPEG,
            map<string|string[]> headers = {}) returns ImageClassificationResult[]|error {
        byte[] imageBytes = check io:fileReadBytes(filePath);
        return self->/hf\-inference/models/[model]/image\-classification.post(
            imageBytes, contentType, headers);
    }

    # Classifies an image fetched from a public URL.
    #
    # + model - The model ID (e.g., `"google/vit-base-patch16-224"`)
    # + imageUrl - Public URL of the image to classify
    # + contentType - Image MIME type (default: `image/jpeg`)
    # + headers - Optional HTTP headers to include in the request
    # + return - An array of `ImageClassificationResult` records, or an error
    resource isolated function post hf\-inference/models/[string model]/image\-classification/url(
            string imageUrl,
            string contentType = IMAGE_JPEG,
            map<string|string[]> headers = {}) returns ImageClassificationResult[]|error {
        http:Client urlClient = check new (imageUrl, {
            followRedirects: {enabled: true, maxCount: 5}
        });
        http:Response imgResp = check urlClient->get("");
        if imgResp.statusCode >= 400 {
            return error(string `Failed to download image from URL: HTTP ${imgResp.statusCode}`);
        }
        byte[] imageBytes = check imgResp.getBinaryPayload();
        string resourcePath = string `/hf-inference/models/${getEncodedUri(model)}`;
        http:Request request = new;
        self.setHeaders(request, headers);
        request.setPayload(imageBytes, contentType);
        http:Response resp = check self.postWithRetry(resourcePath, request);
        json body = check self.handleJsonResponse(resp);
        return check body.fromJsonWithType();
    }

    // ─── Automatic Speech Recognition ────────────────────────────────────────

    # Transcribes audio to text using a speech recognition model.
    #
    # + model - The model ID (e.g., `"openai/whisper-large-v3-turbo"`)
    # + payload - Raw audio bytes
    # + contentType - Audio MIME type (default: `audio/flac`)
    # + headers - Optional HTTP headers to include in the request
    # + return - An `AutomaticSpeechRecognitionResponse` with the transcribed text, or an error
    resource isolated function post hf\-inference/models/[string model]/automatic\-speech\-recognition(
            byte[] payload,
            string contentType = AUDIO_FLAC,
            map<string|string[]> headers = {}) returns AutomaticSpeechRecognitionResponse|error {
        string resourcePath = string `/hf-inference/models/${getEncodedUri(model)}`;
        http:Request request = new;
        self.setHeaders(request, headers);
        request.setPayload(payload, contentType);
        http:Response resp = check self.postWithRetry(resourcePath, request);
        json body = check self.handleJsonResponse(resp);
        return check body.fromJsonWithType();
    }

    # Transcribes audio loaded from a local file path.
    #
    # + model - The model ID (e.g., `"openai/whisper-large-v3-turbo"`)
    # + filePath - Absolute or relative path to the audio file
    # + contentType - Audio MIME type (default: `audio/flac`)
    # + headers - Optional HTTP headers to include in the request
    # + return - An `AutomaticSpeechRecognitionResponse` with the transcribed text, or an error
    resource isolated function post hf\-inference/models/[string model]/automatic\-speech\-recognition/file(
            string filePath,
            string contentType = AUDIO_FLAC,
            map<string|string[]> headers = {}) returns AutomaticSpeechRecognitionResponse|error {
        byte[] audioBytes = check io:fileReadBytes(filePath);
        return self->/hf\-inference/models/[model]/automatic\-speech\-recognition.post(
            audioBytes, contentType, headers);
    }

    # Transcribes audio fetched from a public URL.
    #
    # + model - The model ID (e.g., `"openai/whisper-large-v3-turbo"`)
    # + audioUrl - Public URL of the audio file to transcribe
    # + contentType - Audio MIME type (default: `audio/flac`)
    # + headers - Optional HTTP headers to include in the request
    # + return - An `AutomaticSpeechRecognitionResponse` with the transcribed text, or an error
    resource isolated function post hf\-inference/models/[string model]/automatic\-speech\-recognition/url(
            string audioUrl,
            string contentType = AUDIO_FLAC,
            map<string|string[]> headers = {}) returns AutomaticSpeechRecognitionResponse|error {
        http:Client urlClient = check new (audioUrl, {
            followRedirects: {enabled: true, maxCount: 5}
        });
        http:Response audioResp = check urlClient->get("");
        if audioResp.statusCode >= 400 {
            return error(string `Failed to download audio from URL: HTTP ${audioResp.statusCode}`);
        }
        byte[] audioBytes = check audioResp.getBinaryPayload();
        return self->/hf\-inference/models/[model]/automatic\-speech\-recognition.post(
            audioBytes, contentType, headers);
    }
}