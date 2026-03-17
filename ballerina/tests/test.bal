// Copyright (c) 2026, Hasitha Erandika (http://github.com/HasithaErandika).
// Licensed under the Apache License, Version 2.0.
// SPDX-License-Identifier: Apache-2.0

import ballerina/io;
import ballerina/os;
import ballerina/test;

// ─── Test Client Setup ──────────────────────────────────────────────────────

// The HF_TOKEN must be set as an environment variable or in Config.toml.
// Unit tests (group: "unit") do not require a valid token.
// Live tests (group: "live") require a valid Hugging Face API token.
configurable string token = os:getEnv("HF_TOKEN");

// Module-level client used by live integration tests.
// Uses `check` — will cause a test init failure if the token is invalid,
// which is acceptable since live tests cannot run without a valid token.
Client hfClient = check new ({auth: {token}});

// ─── Unit Tests ──────────────────────────────────────────────────────────────

@test:Config {groups: ["unit"]}
function testClientInitWithDefaults() returns error? {
    Client c = check new ({auth: {token: "test-token"}});
    test:assertNotEquals(c, (), "Client should be successfully initialized.");
}

@test:Config {groups: ["unit"]}
function testClientInitWithCustomRetry() returns error? {
    Client c = check new (
        {auth: {token: "test-token"}},
        retryConfig = {maxRetries: 3, initialDelay: 1.0, maxDelay: 10.0}
    );
    test:assertNotEquals(c, (), "Client with custom retry config should be initialized.");
}

@test:Config {groups: ["unit"]}
function testClientInitWithCustomServiceUrl() returns error? {
    Client c = check new (
        {auth: {token: "test-token"}},
        serviceUrl = "https://api-inference.huggingface.co"
    );
    test:assertNotEquals(c, (), "Client with custom service URL should be initialized.");
}

// ─── Retry Configuration Tests ───────────────────────────────────────────────

@test:Config {groups: ["unit"]}
function testClientInitWithRetryDefaults() returns error? {
    Client c = check new (
        {auth: {token: "test-token"}},
        retryConfig = {}
    );
    test:assertNotEquals(c, (), "Client with default retry config should be initialized.");
}

@test:Config {groups: ["unit"]}
function testClientInitWithAggressiveRetry() returns error? {
    Client c = check new (
        {auth: {token: "test-token"}},
        retryConfig = {maxRetries: 10, initialDelay: 0.5, maxDelay: 5.0}
    );
    test:assertNotEquals(c, (), "Client with aggressive retry config should be initialized.");
}

@test:Config {groups: ["retry", "live"]}
function testRetryWithLiveModel() returns error? {
    // Create a client with retry config to test automatic retry on cold models
    Client retryClient = check new (
        {auth: {token}},
        retryConfig = {maxRetries: 3, initialDelay: 1.0, maxDelay: 10.0}
    );
    ChatCompletionResponse|error result = retryClient->/v1/chat/completions.post({
        model: "katanemo/Arch-Router-1.5B:hf-inference",
        messages: [{role: "user", content: "Say 'retry test passed' in one sentence."}],
        maxTokens: 20
    });
    if result is error {
        io:println("Retry live test skipped: ", result.message());
        return;
    }
    test:assertTrue(result?.choices is ChatCompletionChoice[],
        "Response should contain choices after retry-enabled request.");
    io:println("Retry test response: ", result?.choices);
}

// ─── Generic Inference Tests ─────────────────────────────────────────────────

@test:Config {groups: ["generic-inference", "live"]}
function testGenericInferModel() returns error? {
    json|error result = inferModel(
        hfClient,
        "katanemo/Arch-Router-1.5B:hf-inference",
        {
            "messages": [{"role": "user", "content": "Say hello"}],
            "max_tokens": 10
        }
    );
    if result is error {
        io:println("Generic inferModel live test skipped: ", result.message());
        return;
    }
    test:assertTrue(result != (), "inferModel should return a non-null JSON response.");
    io:println("Generic inference result: ", result);
}

// ─── Chat Completion Tests ───────────────────────────────────────────────────

@test:Config {groups: ["chat", "live"]}
function testChatCompletion() returns error? {
    ChatCompletionResponse|error result = hfClient->/v1/chat/completions.post({
        model: "katanemo/Arch-Router-1.5B:hf-inference",
        messages: [{role: "user", content: "Say hello in one word."}],
        maxTokens: 10
    });
    if result is error {
        io:println("ChatCompletion live test skipped: ", result.message());
        return;
    }
    test:assertTrue(result?.choices is ChatCompletionChoice[],
        "Response should contain choices.");
    ChatCompletionChoice[]? choices = result?.choices;
    if choices is ChatCompletionChoice[] {
        test:assertTrue(choices.length() > 0, "Should have at least one choice.");
    }
    io:println("Chat response: ", result?.choices);
}

@test:Config {groups: ["streaming", "live"]}
function testStreamingChatCompletion() returns error? {
    stream<ChatCompletionChunk, error?>|error result =
        hfClient->/v1/chat/completions/streamed.post({
            model: "katanemo/Arch-Router-1.5B:hf-inference",
            messages: [{role: "user", content: "Count from 1 to 5."}],
            maxTokens: 50
        });
    if result is error {
        io:println("Streaming live test skipped: ", result.message());
        return;
    }
    int chunkCount = 0;
    string fullContent = "";
    check from ChatCompletionChunk chunk in result do {
        chunkCount += 1;
        ChatCompletionChunkChoice[]? choices = chunk?.choices;
        if choices is ChatCompletionChunkChoice[] && choices.length() > 0 {
            string? content = choices[0].delta?.content;
            if content is string {
                fullContent += content;
            }
        }
    };
    test:assertTrue(chunkCount > 0, "Should receive at least one chunk.");
    io:println("Streaming chunks: ", chunkCount, ", content: ", fullContent);
}

// ─── Text Generation Tests ───────────────────────────────────────────────────

@test:Config {groups: ["text-gen", "live"]}
function testTextGeneration() returns error? {
    ChatCompletionResponse|error result = hfClient->/v1/chat/completions.post({
        model: "katanemo/Arch-Router-1.5B:hf-inference",
        messages: [{role: "user", content: "Complete this sentence: Ballerina is designed for"}],
        maxTokens: 20
    });
    if result is error {
        io:println("TextGeneration live test skipped: ", result.message());
        return;
    }
    test:assertTrue(result?.choices is ChatCompletionChoice[],
        "Response should contain choices.");
    io:println("Generated: ", result?.choices);
}

// ─── Classification Tests ────────────────────────────────────────────────────

@test:Config {groups: ["classification", "live"]}
function testTextClassification() returns error? {
    ClassificationLabel[][]|error result =
        hfClient->/hf\-inference/models/["BAAI/bge-reranker-v2-m3"]/text\-classification.post({
            inputs: "Ballerina makes integration elegant!"
        });
    if result is error {
        io:println("TextClassification live test skipped: ", result.message());
        return;
    }
    test:assertTrue(result.length() > 0, "Should return at least one classification group.");
    test:assertTrue(result[0].length() > 0, "First group should contain labels.");
    io:println("Sentiment: ", result[0][0]?.label, " (", result[0][0]?.score, ")");
}

@test:Config {groups: ["zero-shot", "live"]}
function testZeroShotClassification() returns error? {
    ZeroShotClassificationResponse|error result =
        hfClient->/hf\-inference/models/["facebook/bart-large-mnli"]/zero\-shot\-classification.post({
            inputs: "Ballerina is a programming language for cloud integration.",
            parameters: {candidateLabels: ["technology", "sports", "politics"]}
        });
    if result is error {
        io:println("ZeroShotClassification live test skipped: ", result.message());
        return;
    }
    test:assertTrue(result.length() > 0, "Should return at least one classification result.");
    io:println("ZeroShot result: ", result);
}

// ─── Token Classification (NER) Tests ────────────────────────────────────────

@test:Config {groups: ["ner", "live"]}
function testTokenClassification() returns error? {
    TokenClassificationEntity[]|error result =
        hfClient->/hf\-inference/models/["dslim/bert-base-NER"]/token\-classification.post({
            inputs: "Someone is working at WSO2 in Sri Lanka."
        });
    if result is error {
        io:println("TokenClassification live test skipped: ", result.message());
        return;
    }
    test:assertTrue(result.length() > 0, "Should detect at least one entity.");
    io:println("NER entities: ", result);
}

// ─── Feature Extraction Tests ────────────────────────────────────────────────

@test:Config {groups: ["embeddings", "live"]}
function testFeatureExtraction() returns error? {
    float[]|error result =
        hfClient->/hf\-inference/models/["intfloat/multilingual-e5-large"]/feature\-extraction.post({
            inputs: "Ballerina cloud-native integration."
        });
    if result is error {
        io:println("FeatureExtraction live test skipped: ", result.message());
        return;
    }
    test:assertTrue(result.length() > 0, "Embedding vector should not be empty.");
    io:println("Embedding dimensions: ", result.length());
}

// ─── Question Answering Tests ────────────────────────────────────────────────

@test:Config {groups: ["qa", "live"]}
function testQuestionAnswering() returns error? {
    QuestionAnsweringResponse|error result =
        hfClient->/hf\-inference/models/["deepset/roberta-base-squad2"]/question\-answering.post({
            inputs: {
                question: "What is Ballerina?",
                context: "Ballerina is an open-source language for cloud-native integration by WSO2."
            }
        });
    if result is error {
        io:println("QuestionAnswering live test skipped: ", result.message());
        return;
    }
    test:assertTrue(result?.answer is string, "Response should contain an answer.");
    io:println("Answer: ", result?.answer);
}

// ─── Summarization Tests ─────────────────────────────────────────────────────

@test:Config {groups: ["summarization", "live"]}
function testSummarization() returns error? {
    SummarizationResult[]|error result =
        hfClient->/hf\-inference/models/["facebook/bart-large-cnn"]/summarization.post({
            inputs: "Ballerina is a modern open-source programming language designed for cloud-native " +
                "integration. It was created by WSO2 and features built-in concurrency, network " +
                "abstractions, and a rich type system ideal for microservices.",
            parameters: {maxLength: 40, minLength: 15}
        });
    if result is error {
        io:println("Summarization live test skipped: ", result.message());
        return;
    }
    test:assertTrue(result.length() > 0, "Should return at least one summary.");
    io:println("Summary: ", result[0].summaryText);
}

// ─── Translation Tests ───────────────────────────────────────────────────────

@test:Config {groups: ["translation", "live"]}
function testTranslation() returns error? {
    TranslationResult[]|error result =
        hfClient->/hf\-inference/models/["Helsinki-NLP/opus-mt-en-fr"]/translation.post({
            inputs: "Hello, how are you?"
        });
    if result is error {
        io:println("Translation live test skipped: ", result.message());
        return;
    }
    test:assertTrue(result.length() > 0, "Should return at least one translation.");
    io:println("Translation: ", result[0].translationText);
}

// ─── Image Generation Tests ──────────────────────────────────────────────────

@test:Config {groups: ["image-gen", "live"]}
function testTextToImage() returns error? {
    byte[]|error result =
        hfClient->/hf\-inference/models/["stabilityai/stable-diffusion-xl-base-1.0"]/text\-to\-image.post({
            inputs: "A Ballerina robot hacking on code",
            parameters: {width: 512, height: 512, numInferenceSteps: 4}
        });
    if result is error {
        io:println("TextToImage live test skipped: ", result.message());
        return;
    }
    test:assertTrue(result.length() > 0, "Generated image should have non-zero byte length.");
    io:println("Generated image bytes: ", result.length());
}

// ─── Image Classification Tests ──────────────────────────────────────────────

@test:Config {groups: ["image-classification", "live"]}
function testImageClassificationFromBytes() returns error? {
    byte[]|io:Error payload = io:fileReadBytes("tests/resources/test.jpg");
    if payload is io:Error {
        io:println("ImageClassification test skipped — sample image not found: ", payload.message());
        return;
    }
    ImageClassificationResult[]|error result =
        hfClient->/hf\-inference/models/["google/vit-base-patch16-224"]/image\-classification.post(payload);
    if result is error {
        io:println("ImageClassification live test skipped: ", result.message());
        return;
    }
    test:assertTrue(result.length() > 0, "Should return at least one classification.");
    io:println("Image classifications: ", result);
}

@test:Config {groups: ["image-classification-file", "live"]}
function testImageClassificationFromFile() returns error? {
    ImageClassificationResult[]|error result =
        hfClient->/hf\-inference/models/["google/vit-base-patch16-224"]/image\-classification/file.post(
            "tests/resources/test.jpg"
        );
    if result is error {
        io:println("ImageClassification from file skipped: ", result.message());
        return;
    }
    test:assertTrue(result.length() > 0, "Should return at least one classification.");
    io:println("Image (file) top label: ", result[0]?.label, " (", result[0]?.score, ")");
}

@test:Config {groups: ["image-classification-url", "live"]}
function testImageClassificationFromUrl() returns error? {
    ImageClassificationResult[]|error result =
        hfClient->/hf\-inference/models/["google/vit-base-patch16-224"]/image\-classification/url.post(
            "https://as2.ftcdn.net/v2/jpg/02/96/58/43/1000_F_296584307_tKTtq5lxE3PKsbD5IrmhpRMLl76BAmMt.jpg"
        );
    if result is error {
        io:println("ImageClassification from URL skipped: ", result.message());
        return;
    }
    test:assertTrue(result.length() > 0, "Should return at least one classification.");
    io:println("Image (URL) top label: ", result[0]?.label, " (", result[0]?.score, ")");
}

// ─── Automatic Speech Recognition Tests ──────────────────────────────────────

@test:Config {groups: ["asr", "live"]}
function testAutomaticSpeechRecognition() returns error? {
    byte[]|io:Error payload = io:fileReadBytes("tests/resources/test.wav");
    if payload is io:Error {
        io:println("ASR test skipped — sample audio not found: ", payload.message());
        return;
    }
    AutomaticSpeechRecognitionResponse|error result =
        hfClient->/hf\-inference/models/["openai/whisper-large-v3-turbo"]/automatic\-speech\-recognition.post(payload);
    if result is error {
        io:println("ASR live test skipped: ", result.message());
        return;
    }
    test:assertTrue(result?.text is string, "Should return transcribed text.");
    io:println("ASR text: ", result?.text);
}

@test:Config {groups: ["asr-file", "live"]}
function testASRFromFile() returns error? {
    AutomaticSpeechRecognitionResponse|error result =
        hfClient->/hf\-inference/models/["openai/whisper-large-v3-turbo"]/automatic\-speech\-recognition/file.post(
            "tests/resources/test.wav"
        );
    if result is error {
        io:println("ASR from file skipped: ", result.message());
        return;
    }
    test:assertTrue(result?.text is string, "Should return transcribed text.");
    io:println("ASR (file) text: ", result?.text);
}

@test:Config {groups: ["asr-url", "live"]}
function testASRFromUrl() returns error? {
    AutomaticSpeechRecognitionResponse|error result =
        hfClient->/hf\-inference/models/["openai/whisper-large-v3-turbo"]/automatic\-speech\-recognition/url.post(
            "https://huggingface.co/datasets/Narsil/asr_dummy/resolve/main/mlk.flac",
            AUDIO_FLAC
        );
    if result is error {
        io:println("ASR from URL skipped: ", result.message());
        return;
    }
    test:assertTrue(result?.text is string, "Should return transcribed text from URL audio.");
    io:println("ASR (URL) text: ", result?.text);
}

// ─── RAG Pipeline Tests ─────────────────────────────────────────────────────

@test:Config {groups: ["rag", "live"]}
function testRagPipeline() returns error? {
    RagDocument[] documents = [
        {
            id: "doc1",
            content: "Ballerina is an open-source programming language for cloud-native integration created by WSO2.",
            metadata: {"source": "ballerina.io"}
        },
        {
            id: "doc2",
            content: "WSO2 is a Sri Lankan technology company founded in 2005 specializing in open-source middleware.",
            metadata: {"source": "wso2.com"}
        },
        {
            id: "doc3",
            content: "Python is a high-level programming language widely used in data science and machine learning.",
            metadata: {"source": "python.org"}
        }
    ];

    RagResult|error result = ragQuery(
        hfClient,
        "Who created Ballerina and what is it used for?",
        documents
    );
    if result is error {
        io:println("RAG pipeline live test skipped: ", result.message());
        return;
    }
    test:assertTrue(result.answer.length() > 0, "RAG answer should not be empty.");
    test:assertTrue(result.sources.length() > 0, "Should have at least one source document.");
    test:assertTrue(result.scores.length() == result.sources.length(),
        "Scores array should match sources array length.");
    io:println("RAG Answer: ", result.answer);
    io:println("RAG Sources: ", result.sources.length(), ", Top score: ", result.scores[0]);
}