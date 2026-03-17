// Copyright (c) 2026, Hasitha Erandika (http://github.com/HasithaErandika).
// Licensed under the Apache License, Version 2.0.
// SPDX-License-Identifier: Apache-2.0

import ballerina/data.jsondata;
import ballerina/http;

// ─── Connection & Configuration ──────────────────────────────────────────────

# Provides configurations for controlling the behaviours when communicating with the Hugging Face Inference API.
#
# + auth - Bearer token configuration for API authentication
# + httpVersion - HTTP protocol version (default: HTTP/2)
# + http1Settings - HTTP/1.x specific configurations
# + http2Settings - HTTP/2 specific configurations
# + timeout - Request timeout in seconds (default: 30)
# + forwarded - Handling mode for `Forwarded`/`X-Forwarded` headers
# + followRedirects - Redirect following configuration
# + poolConfig - Connection pool configuration
# + cache - HTTP response cache configuration
# + compression - Request/response compression setting
# + circuitBreaker - Circuit breaker configuration for fault tolerance
# + retryConfig - HTTP-level retry configuration (separate from model loading retries)
# + cookieConfig - Cookie handling configuration
# + responseLimits - Response size limit configurations
# + secureSocket - SSL/TLS configuration for HTTPS connections
# + proxy - HTTP proxy configuration
# + socketConfig - Low-level socket configuration
# + validation - Whether to validate constraints on request/response payloads
# + laxDataBinding - Whether to use relaxed data binding for responses
@display {label: "Connection Config"}
public type ConnectionConfig record {|
    http:BearerTokenConfig auth;
    http:HttpVersion httpVersion = http:HTTP_2_0;
    http:ClientHttp1Settings http1Settings = {};
    http:ClientHttp2Settings http2Settings = {};
    decimal timeout = 30;
    string forwarded = "disable";
    http:FollowRedirects followRedirects?;
    http:PoolConfiguration poolConfig?;
    http:CacheConfig cache = {};
    http:Compression compression = http:COMPRESSION_AUTO;
    http:CircuitBreakerConfig circuitBreaker?;
    http:RetryConfig retryConfig?;
    http:CookieConfig cookieConfig?;
    http:ResponseLimitConfigs responseLimits = {};
    http:ClientSecureSocket secureSocket?;
    http:ProxyConfig proxy?;
    http:ClientSocketConfig socketConfig = {};
    boolean validation = true;
    boolean laxDataBinding = true;
|};

# Configuration for automatic retry behaviour when a model is cold-starting (HTTP 503).
#
# + maxRetries - Maximum number of retry attempts (default: 5)
# + initialDelay - Initial delay in seconds before the first retry (default: 2.0)
# + maxDelay - Maximum delay in seconds between retries after exponential backoff (default: 30.0)
public type RetryConfig record {|
    int maxRetries = 5;
    decimal initialDelay = 2.0;
    decimal maxDelay = 30.0;
|};

// ─── Chat Completion Types ──────────────────────────────────────────────────

# A single message in a chat conversation.
#
# + role - The role of the message author (e.g., `"user"`, `"assistant"`, `"system"`)
# + content - The text content of the message
public type ChatMessage record {
    string role;
    string content;
};

# Request body for the chat completion endpoint.
#
# + maxTokens - Maximum number of tokens to generate
# + temperature - Sampling temperature (0.0 = deterministic, higher = more random)
# + messages - The conversation history as an array of messages
# + model - The model ID to use (e.g., `"katanemo/Arch-Router-1.5B:hf-inference"`)
public type ChatCompletionRequest record {
    @jsondata:Name {value: "max_tokens"}
    int maxTokens?;
    float temperature?;
    ChatMessage[] messages;
    string model;
};

# A single completion choice returned by the chat API.
#
# + finishReason - Why the model stopped generating (e.g., `"stop"`, `"length"`)
# + index - The index of this choice in the list of choices
# + message - The generated message content
public type ChatCompletionChoice record {
    @jsondata:Name {value: "finish_reason"}
    string finishReason?;
    int index?;
    ChatMessage message?;
};

# Response from the chat completion endpoint.
#
# + id - Unique identifier for the completion
# + choices - The list of generated completion choices
public type ChatCompletionResponse record {
    string id?;
    ChatCompletionChoice[] choices?;
};

// ─── Streaming Chat Completion Types ─────────────────────────────────────────

# Delta content in a streaming chat completion chunk.
#
# + role - The role of the message author (present only in the first chunk)
# + content - A token fragment of the generated content
public type ChatCompletionChunkDelta record {
    string role?;
    string content?;
};

# A single choice within a streaming chat completion chunk.
#
# + index - The index of this choice
# + delta - The incremental content for this chunk
# + finishReason - Present only in the final chunk (e.g., `"stop"`)
public type ChatCompletionChunkChoice record {
    int index?;
    ChatCompletionChunkDelta delta?;
    @jsondata:Name {value: "finish_reason"}
    string? finishReason?;
};

# A single chunk in a streaming chat completion response.
#
# + id - Unique identifier shared across all chunks of the same completion
# + 'object - The object type (typically `"chat.completion.chunk"`)
# + created - Unix timestamp when the chunk was created
# + model - The model that generated this chunk
# + choices - The list of chunk choices
public type ChatCompletionChunk record {
    string id?;
    string 'object?;
    int created?;
    string model?;
    ChatCompletionChunkChoice[] choices?;
};

// ─── Text Generation Types ──────────────────────────────────────────────────

# Parameters for controlling text generation behaviour.
#
# + maxNewTokens - Maximum number of new tokens to generate
# + temperature - Sampling temperature (0.0 = deterministic, higher = more random)
# + returnFullText - If `true`, returns the prompt concatenated with the generated text
public type TextGenerationParameters record {
    @jsondata:Name {value: "max_new_tokens"}
    int maxNewTokens?;
    float temperature?;
    @jsondata:Name {value: "return_full_text"}
    boolean returnFullText?;
};

# Request body for the text generation endpoint.
#
# + inputs - The text prompt to continue generating from
# + parameters - Optional generation parameters
public type TextGenerationRequest record {
    string inputs;
    TextGenerationParameters parameters?;
};

# A single text generation result.
#
# + generatedText - The generated continuation text
public type TextGenerationResult record {
    @jsondata:Name {value: "generated_text"}
    string generatedText?;
};

// ─── Classification Types ───────────────────────────────────────────────────

# Request body for the text classification endpoint.
#
# + inputs - The text to classify
public type TextClassificationRequest record {
    string inputs;
};

# A classification label with its confidence score.
#
# + score - Confidence score between 0.0 and 1.0
# + label - The predicted label name
public type ClassificationLabel record {
    float score?;
    string label?;
};

// ─── Token Classification Types ─────────────────────────────────────────────

# Request body for the token classification (NER) endpoint.
#
# + inputs - The text to analyse for named entities
public type TokenClassificationRequest record {
    string inputs;
};

# A named entity recognised by token classification.
#
# + score - Confidence score of the entity detection
# + entityGroup - The entity category (e.g., `"PER"`, `"ORG"`, `"LOC"`)
# + 'start - Start character offset of the entity in the input text
# + end - End character offset of the entity in the input text
# + word - The entity text as it appears in the input
public type TokenClassificationEntity record {
    float score?;
    @jsondata:Name {value: "entity_group"}
    string entityGroup?;
    int 'start?;
    int end?;
    string word?;
};

// ─── Feature Extraction Types ───────────────────────────────────────────────

# Request body for the feature extraction (embeddings) endpoint.
#
# + inputs - The text to generate embeddings for
public type FeatureExtractionRequest record {
    string inputs;
};

// ─── Question Answering Types ───────────────────────────────────────────────

# The question and context pair for question answering.
#
# + question - The question to answer
# + context - The context paragraph from which to extract the answer
public type QuestionAnsweringInputs record {
    string question;
    string context;
};

# Request body for the question answering endpoint.
#
# + inputs - The question and context pair
public type QuestionAnsweringRequest record {
    QuestionAnsweringInputs inputs;
};

# Response from the question answering endpoint.
#
# + score - Confidence score of the extracted answer
# + answer - The extracted answer text
# + 'start - Start character offset of the answer in the context
# + end - End character offset of the answer in the context
public type QuestionAnsweringResponse record {
    float score?;
    string answer?;
    int 'start?;
    int end?;
};

// ─── Summarization Types ────────────────────────────────────────────────────

# Parameters for controlling summarization behaviour.
#
# + minLength - Minimum length of the generated summary in tokens
# + maxLength - Maximum length of the generated summary in tokens
public type SummarizationParameters record {
    @jsondata:Name {value: "min_length"}
    int minLength?;
    @jsondata:Name {value: "max_length"}
    int maxLength?;
};

# Request body for the summarization endpoint.
#
# + inputs - The text to summarize
# + parameters - Optional summarization parameters
public type SummarizationRequest record {
    string inputs;
    SummarizationParameters parameters?;
};

# A single summarization result.
#
# + summaryText - The generated summary text
public type SummarizationResult record {
    @jsondata:Name {value: "summary_text"}
    string summaryText?;
};

// ─── Translation Types ──────────────────────────────────────────────────────

# Request body for the translation endpoint.
#
# + inputs - The text to translate
public type TranslationRequest record {
    string inputs;
};

# A single translation result.
#
# + translationText - The translated text
public type TranslationResult record {
    @jsondata:Name {value: "translation_text"}
    string translationText?;
};

// ─── Zero-Shot Classification Types ─────────────────────────────────────────

# Parameters for the zero-shot classification endpoint.
#
# + candidateLabels - The list of candidate labels to classify against
public type ZeroShotClassificationRequestParameters record {
    @jsondata:Name {value: "candidate_labels"}
    string[] candidateLabels;
};

# Request body for the zero-shot classification endpoint.
#
# + inputs - The text to classify
# + parameters - Parameters including candidate labels
public type ZeroShotClassificationRequest record {
    string inputs;
    ZeroShotClassificationRequestParameters parameters;
};

# A single zero-shot classification result with label and score.
#
# + label - The candidate label
# + score - Confidence score for this label
public type ZeroShotClassificationItem record {
    string label?;
    float score?;
};

# Response from the zero-shot classification endpoint (array of scored labels).
public type ZeroShotClassificationResponse ZeroShotClassificationItem[];

// ─── Image Classification Types ─────────────────────────────────────────────

# A single image classification result.
#
# + score - Confidence score for the predicted class
# + label - The predicted class label
public type ImageClassificationResult record {
    float score?;
    string label?;
};

// ─── Text-to-Image Types ────────────────────────────────────────────────────

# Parameters for the text-to-image generation endpoint.
#
# + width - Width of the generated image in pixels
# + height - Height of the generated image in pixels
# + numInferenceSteps - Number of diffusion inference steps (higher = better quality, slower)
public type TextToImageParameters record {
    int width?;
    int height?;
    @jsondata:Name {value: "num_inference_steps"}
    int numInferenceSteps?;
};

# Request body for the text-to-image generation endpoint.
#
# + inputs - The text prompt describing the image to generate
# + parameters - Optional image generation parameters
public type TextToImageRequest record {
    string inputs;
    TextToImageParameters parameters?;
};

// ─── Automatic Speech Recognition Types ─────────────────────────────────────

# Response from the automatic speech recognition endpoint.
#
# + text - The transcribed text from the audio input
public type AutomaticSpeechRecognitionResponse record {
    string text?;
};

// ─── Multi-Modal Content Type Enums ─────────────────────────────────────────

# Supported image content types for vision tasks.
public enum ImageContentType {
    IMAGE_JPEG = "image/jpeg",
    IMAGE_PNG = "image/png",
    IMAGE_WEBP = "image/webp",
    IMAGE_BMP = "image/bmp",
    IMAGE_GIF = "image/gif",
    IMAGE_TIFF = "image/tiff"
}

# Supported audio content types for speech recognition.
public enum AudioContentType {
    AUDIO_FLAC = "audio/flac",
    AUDIO_WAV = "audio/wav",
    AUDIO_MPEG = "audio/mpeg",
    AUDIO_OGG = "audio/ogg",
    AUDIO_WEBM = "audio/webm",
    AUDIO_M4A = "audio/m4a"
}

// ─── RAG Types ──────────────────────────────────────────────────────────────

# A document with its content and optional metadata for RAG operations.
#
# + id - Unique identifier for the document
# + content - The document text content used for embedding and context
# + metadata - Optional key-value metadata (e.g., source URL, author)
public type RagDocument record {|
    string id;
    string content;
    map<string> metadata?;
|};

# Result from a RAG query including the answer and source documents used.
#
# + answer - The generated answer grounded in the source documents
# + sources - The top-K most relevant documents used as context
# + scores - Cosine similarity scores corresponding to each source document
public type RagResult record {|
    string answer;
    RagDocument[] sources;
    float[] scores;
|};
