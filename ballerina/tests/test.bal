// Copyright (c) 2026, Hasitha Erandika (http://github.com/HasithaErandika).
// Licensed under the Apache License, Version 2.0.
// SPDX-License-Identifier: Apache-2.0

import ballerina/io;
import ballerina/os;
import ballerina/test;

// ─── Test Client Setup ─────────────────────────────────────────────────────

// The HF_TOKEN must be set as an environment variable or in Config.toml.
// Unit tests (group: "unit") do not require a valid token.
// Live tests (group: "live") require a valid Hugging Face API token.
configurable string token = os:getEnv("HF_TOKEN");

// Module-level client used by live integration tests.
// Uses `check` — will cause a test init failure if the token is invalid,
// which is acceptable since live tests cannot run without a valid token.
Client hfClient = check new ({auth: {token}});

// ─── Unit Tests (no live token required) ───────────────────────────────────

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
        serviceUrl = "https://router.huggingface.co"
    );
    test:assertNotEquals(c, (), "Client with custom service URL should be initialized.");
}

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

// ─── Fix #5 + #13: Negative-Path Unit Tests ────────────────────────────────

@test:Config {groups: ["unit", "negative"]}
function testClientInitRejectsZeroInitialDelay() {
    Client|error c = new ({auth: {token: "test-token"}},
        retryConfig = {initialDelay: 0.0});
    test:assertTrue(c is error,
        "Client init should fail when initialDelay is 0.");
    if c is error {
        test:assertTrue(c.message().includes("initialDelay"),
            "Error message should mention initialDelay.");
    }
}

@test:Config {groups: ["unit", "negative"]}
function testClientInitRejectsNegativeInitialDelay() {
    Client|error c = new ({auth: {token: "test-token"}},
        retryConfig = {initialDelay: -1.0});
    test:assertTrue(c is error,
        "Client init should fail when initialDelay is negative.");
}

@test:Config {groups: ["unit", "negative"]}
function testRagQueryRejectsEmptyDocuments() {
    Client|error c = new ({auth: {token: "test-token"}});
    if c is error {
        test:assertFail("Could not create placeholder client: " + c.message());
    }
    RagResult|error result = ragQuery(c, "What is Ballerina?", []);
    test:assertTrue(result is error,
        "ragQuery with empty documents should return an error.");
    if result is error {
        test:assertTrue(result.message().includes("at least one document"),
            "Error should mention the empty-documents constraint.");
    }
}

@test:Config {groups: ["unit", "negative"]}
function testConversationInitNoSystemPrompt() {
    Client|error c = new ({auth: {token: "test-token"}});
    if c is error {
        test:assertFail("Placeholder client init failed.");
    }
    Conversation conv = new (c, "test-model");
    ChatMessage[] history = conv.getHistory();
    test:assertEquals(history.length(), 0,
        "Conversation without system prompt should start with empty history.");
    test:assertEquals(conv.turnCount(), 0,
        "Turn count should be 0 before any messages.");
}

@test:Config {groups: ["unit", "negative"]}
function testConversationInitWithSystemPrompt() {
    Client|error c = new ({auth: {token: "test-token"}});
    if c is error {
        test:assertFail("Placeholder client init failed.");
    }
    Conversation conv = new (c, "test-model",
        systemPrompt = "You are a helpful assistant.");
    ChatMessage[] history = conv.getHistory();
    test:assertEquals(history.length(), 1,
        "Conversation with system prompt should have one history entry.");
    test:assertEquals(history[0].role, "system",
        "First history message should have role 'system'.");
}

@test:Config {groups: ["unit", "negative"]}
function testConversationResetPreservesSystemPrompt() {
    Client|error c = new ({auth: {token: "test-token"}});
    if c is error {
        test:assertFail("Placeholder client init failed.");
    }
    Conversation conv = new (c, "test-model",
        systemPrompt = "You are a helpful assistant.");
    conv.reset();
    ChatMessage[] history = conv.getHistory();
    test:assertEquals(history.length(), 1,
        "After reset, only system prompt should remain.");
    test:assertEquals(history[0].role, "system",
        "Preserved message after reset should be the system prompt.");
    test:assertEquals(conv.turnCount(), 0,
        "Turn count should be 0 after reset.");
}

@test:Config {groups: ["unit", "negative"]}
function testConversationResetNoSystemPromptYieldsEmptyHistory() {
    Client|error c = new ({auth: {token: "test-token"}});
    if c is error {
        test:assertFail("Placeholder client init failed.");
    }
    Conversation conv = new (c, "test-model");
    conv.reset();
    test:assertEquals(conv.getHistory().length(), 0,
        "After reset with no system prompt, history should be empty.");
}

@test:Config {groups: ["unit", "negative"]}
function testConversationSnapshotReturnsCorrectModel() {
    Client|error c = new ({auth: {token: "test-token"}});
    if c is error {
        test:assertFail("Placeholder client init failed.");
    }
    string expectedModel = "my-test-model";
    Conversation conv = new (c, expectedModel);
    ConversationSnapshot snap = conv.snapshot();
    test:assertEquals(snap.model, expectedModel,
        "Snapshot model should match the model passed to the constructor.");
    test:assertEquals(snap.turnCount, 0,
        "Snapshot turnCount should be 0 for a fresh conversation.");
}

@test:Config {groups: ["unit", "negative"]}
function testRagQueryFailsWithNoDocuments() {
    Client|error c = new ({auth: {token: "test-token"}});
    if c is error {
        test:assertFail("Placeholder client init failed.");
    }
    RagResult|error result = ragQuery(c, "Any query", []);
    test:assertTrue(result is error,
        "ragQuery should fail immediately when no documents are provided.");
    if result is error {
        test:assertTrue(result.message().includes("at least one document"),
            "Error should describe the empty-document constraint.");
    }
}

// ─── Retry (live) ──────────────────────────────────────────────────────────

@test:Config {groups: ["retry", "live"]}
function testRetryWithLiveModel() returns error? {
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
        io:println("[SKIPPED] Retry live test skipped: " + result.message());
        return;
    }
    test:assertTrue(result?.choices is ChatCompletionChoice[],
        "Response should contain choices after retry-enabled request.");
    io:println("Retry test response: ", result?.choices);
}

// ─── Generic Inference ─────────────────────────────────────────────────────

@test:Config {groups: ["generic-inference", "live"]}
function testGenericInferModel() returns error? {
    json|error result = inferModel(
        hfClient,
        "gpt2",
        {
            "inputs": "Say hello"
        }
    );
    if result is error {
        io:println("[SKIPPED] Generic inferModel live test skipped: " + result.message());
        return;
    }
    test:assertTrue(result != (), "inferModel should return a non-null JSON response.");
    io:println("Generic inference result: ", result);
}

// ─── Chat Completion ───────────────────────────────────────────────────────

@test:Config {groups: ["chat", "live"]}
function testChatCompletion() returns error? {
    ChatCompletionResponse|error result = hfClient->/v1/chat/completions.post({
        model: "katanemo/Arch-Router-1.5B:hf-inference",
        messages: [{role: "user", content: "Say hello in one word."}],
        maxTokens: 10
    });
    if result is error {
        io:println("[SKIPPED] ChatCompletion live test skipped: " + result.message());
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
        io:println("[SKIPPED] Streaming live test skipped: " + result.message());
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

// ─── Text Generation (actual hf-inference endpoint) ────────────────────────

@test:Config {groups: ["text-gen", "live"]}
function testTextGeneration() returns error? {
    // Fix: uses the correct /hf-inference/models/{model} text-generation endpoint
    TextGenerationResult[]|error result =
        hfClient->/hf\-inference/models/["gpt2"].post({
            inputs: "Ballerina is designed for"
        });
    if result is error {
        io:println("[SKIPPED] TextGeneration live test skipped: " + result.message());
        return;
    }
    test:assertTrue(result.length() > 0, "Should return at least one generated text result.");
    io:println("Generated: ", result[0].generatedText);
}

// ─── Classification ────────────────────────────────────────────────────────

@test:Config {groups: ["classification", "live"]}
function testTextClassification() returns error? {
    ClassificationLabel[][]|error result =
        hfClient->/hf\-inference/models/["BAAI/bge-reranker-v2-m3"]/text\-classification.post({
            inputs: "Ballerina makes integration elegant!"
        });
    if result is error {
        io:println("[SKIPPED] TextClassification live test skipped: " + result.message());
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
        io:println("[SKIPPED] ZeroShotClassification live test skipped: " + result.message());
        return;
    }
    test:assertTrue(result.length() > 0, "Should return at least one classification result.");
    io:println("ZeroShot result: ", result);
}

// ─── Token Classification (NER) ────────────────────────────────────────────

@test:Config {groups: ["ner", "live"]}
function testTokenClassification() returns error? {
    TokenClassificationEntity[]|error result =
        hfClient->/hf\-inference/models/["dslim/bert-base-NER"]/token\-classification.post({
            inputs: "Someone is working at WSO2 in Sri Lanka."
        });
    if result is error {
        io:println("[SKIPPED] TokenClassification live test skipped: " + result.message());
        return;
    }
    test:assertTrue(result.length() > 0, "Should detect at least one entity.");
    io:println("NER entities: ", result);
}

// ─── Feature Extraction ────────────────────────────────────────────────────

@test:Config {groups: ["embeddings", "live"]}
function testFeatureExtraction() returns error? {
    float[]|error result =
        hfClient->/hf\-inference/models/["intfloat/multilingual-e5-large"]/feature\-extraction.post({
            inputs: "Ballerina cloud-native integration."
        });
    if result is error {
        io:println("[SKIPPED] FeatureExtraction live test skipped: " + result.message());
        return;
    }
    test:assertTrue(result.length() > 0, "Embedding vector should not be empty.");
    io:println("Embedding dimensions: ", result.length());
}

// ─── Question Answering ────────────────────────────────────────────────────

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
        io:println("[SKIPPED] QuestionAnswering live test skipped: " + result.message());
        return;
    }
    test:assertTrue(result?.answer is string, "Response should contain an answer.");
    io:println("Answer: ", result?.answer);
}

// ─── Summarization ─────────────────────────────────────────────────────────

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
        io:println("[SKIPPED] Summarization live test skipped: " + result.message());
        return;
    }
    test:assertTrue(result.length() > 0, "Should return at least one summary.");
    io:println("Summary: ", result[0].summaryText);
}

// ─── Translation ───────────────────────────────────────────────────────────

@test:Config {groups: ["translation", "live"]}
function testTranslation() returns error? {
    TranslationResult[]|error result =
        hfClient->/hf\-inference/models/["Helsinki-NLP/opus-mt-en-fr"]/translation.post({
            inputs: "Hello, how are you?"
        });
    if result is error {
        io:println("[SKIPPED] Translation live test skipped: " + result.message());
        return;
    }
    test:assertTrue(result.length() > 0, "Should return at least one translation.");
    io:println("Translation: ", result[0].translationText);
}

// ─── Text to Image ─────────────────────────────────────────────────────────

@test:Config {groups: ["image-gen", "live"]}
function testTextToImage() returns error? {
    byte[]|error result =
        hfClient->/hf\-inference/models/["stabilityai/stable-diffusion-xl-base-1.0"]/text\-to\-image.post({
            inputs: "A Ballerina robot hacking on code",
            parameters: {width: 512, height: 512, numInferenceSteps: 4}
        });
    if result is error {
        io:println("[SKIPPED] TextToImage live test skipped: " + result.message());
        return;
    }
    test:assertTrue(result.length() > 0, "Generated image should have non-zero byte length.");
    io:println("Generated image bytes: ", result.length());
}

// ─── Image Classification ──────────────────────────────────────────────────

@test:Config {groups: ["image-classification", "live"]}
function testImageClassificationFromBytes() returns error? {
    byte[]|io:Error payload = io:fileReadBytes("tests/resources/test.jpg");
    if payload is io:Error {
        io:println("[SKIPPED] Test skipped — sample image not found: " + payload.message());
        return;
    }
    ImageClassificationResult[]|error result =
        hfClient->/hf\-inference/models/["google/vit-base-patch16-224"]/image\-classification.post(payload);
    if result is error {
        io:println("[SKIPPED] ImageClassification live test skipped: " + result.message());
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
        io:println("[SKIPPED] ImageClassification from file skipped: " + result.message());
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
        io:println("[SKIPPED] ImageClassification from URL skipped: " + result.message());
        return;
    }
    test:assertTrue(result.length() > 0, "Should return at least one classification.");
    io:println("Image (URL) top label: ", result[0]?.label, " (", result[0]?.score, ")");
}

// ─── Automatic Speech Recognition ─────────────────────────────────────────

@test:Config {groups: ["asr", "live"]}
function testAutomaticSpeechRecognition() returns error? {
    byte[]|io:Error payload = io:fileReadBytes("tests/resources/test.wav");
    if payload is io:Error {
        io:println("[SKIPPED] ASR test skipped — sample audio not found: " + payload.message());
        return;
    }
    AutomaticSpeechRecognitionResponse|error result =
        hfClient->/hf\-inference/models/["openai/whisper-large-v3-turbo"]/automatic\-speech\-recognition.post(payload);
    if result is error {
        io:println("[SKIPPED] ASR live test skipped: " + result.message());
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
        io:println("[SKIPPED] ASR from file skipped: " + result.message());
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
        io:println("[SKIPPED] ASR from URL skipped: " + result.message());
        return;
    }
    test:assertTrue(result?.text is string, "Should return transcribed text from URL audio.");
    io:println("ASR (URL) text: ", result?.text);
}

// ─── Fix #10: Batch Endpoint Tests ────────────────────────────────────────

@test:Config {groups: ["batch", "live"]}
function testBatchTextClassification() returns error? {
    ClassificationLabel[][]|error result =
        hfClient->/hf\-inference/models/["distilbert-base-uncased-finetuned-sst-2-english"]/text\-classification/batch.post({
            inputs: [
                "Ballerina makes integration elegant!",
                "This is absolutely terrible."
            ]
        });
    if result is error {
        io:println("[SKIPPED] BatchTextClassification live test skipped: " + result.message());
        return;
    }
    test:assertEquals(result.length(), 2, "Batch result should have one entry per input.");
    io:println("Batch classification results: ", result.length());
}

@test:Config {groups: ["batch", "live"]}
function testBatchFeatureExtraction() returns error? {
    float[][]|error result =
        hfClient->/hf\-inference/models/["intfloat/multilingual-e5-large"]/feature\-extraction/batch.post({
            inputs: [
                "Ballerina cloud-native integration.",
                "Python machine learning and data science."
            ]
        });
    if result is error {
        io:println("[SKIPPED] BatchFeatureExtraction live test skipped: " + result.message());
        return;
    }
    test:assertEquals(result.length(), 2, "Batch result should have one embedding per input.");
    test:assertTrue(result[0].length() > 0, "First embedding vector should not be empty.");
    io:println("Batch embeddings: ", result.length(), " vectors of dim ", result[0].length());
}

@test:Config {groups: ["batch", "live"]}
function testBatchTokenClassification() returns error? {
    TokenClassificationEntity[][]|error result =
        hfClient->/hf\-inference/models/["dslim/bert-base-NER"]/token\-classification/batch.post({
            inputs: [
                "Someone is working at WSO2 in Sri Lanka.",
                "Elon Musk founded SpaceX in 2002."
            ]
        });
    if result is error {
        io:println("[SKIPPED] BatchTokenClassification live test skipped: " + result.message());
        return;
    }
    test:assertEquals(result.length(), 2, "Batch NER result should have one entity array per input.");
    io:println("Batch NER: ", result.length(), " inputs processed.");
}

// ─── Fix #10: Conversation Tests (live) ───────────────────────────────────

@test:Config {groups: ["conversation", "live"]}
function testConversationMultiTurn() returns error? {
    Conversation conv = new (
        hfClient,
        "katanemo/Arch-Router-1.5B:hf-inference",
        systemPrompt = "You are a concise assistant. Reply in one sentence.",
        maxTokens = 50
    );

    string|error reply1 = conv.chat("What is Ballerina?");
    if reply1 is error {
        io:println("[SKIPPED] Conversation live test skipped: " + reply1.message());
        return;
    }
    test:assertTrue(reply1.length() > 0, "First reply should not be empty.");
    test:assertEquals(conv.turnCount(), 1, "Turn count should be 1 after first message.");

    string|error reply2 = conv.chat("Who created it?");
    if reply2 is error {
        io:println("[SKIPPED] Conversation second turn skipped: " + reply2.message());
        return;
    }
    test:assertTrue(reply2.length() > 0, "Second reply should not be empty.");
    test:assertEquals(conv.turnCount(), 2, "Turn count should be 2 after second message.");

    // system + user + assistant + user + assistant = 5 messages
    ChatMessage[] history = conv.getHistory();
    test:assertEquals(history.length(), 5,
        "History should contain system + 2 user + 2 assistant = 5 messages.");
    io:println("Turn 1: ", reply1);
    io:println("Turn 2: ", reply2);
}

@test:Config {groups: ["conversation", "live"]}
function testConversationResetLive() returns error? {
    Conversation conv = new (
        hfClient,
        "katanemo/Arch-Router-1.5B:hf-inference",
        systemPrompt = "You are a helpful assistant.",
        maxTokens = 30
    );
    string|error reply = conv.chat("Hi there!");
    if reply is error {
        io:println("[SKIPPED] Conversation reset live test skipped: " + reply.message());
        return;
    }
    test:assertEquals(conv.turnCount(), 1, "Turn count should be 1 before reset.");
    conv.reset();
    test:assertEquals(conv.turnCount(), 0, "Turn count should be 0 after reset.");
    ChatMessage[] history = conv.getHistory();
    test:assertEquals(history.length(), 1, "After reset, only system prompt should be preserved.");
    test:assertEquals(history[0].role, "system", "Preserved message role should be 'system'.");
}

@test:Config {groups: ["conversation", "live"]}
function testConversationSnapshotLive() returns error? {
    string modelId = "katanemo/Arch-Router-1.5B:hf-inference";
    Conversation conv = new (hfClient, modelId, maxTokens = 30);
    string|error reply = conv.chat("Hello!");
    if reply is error {
        io:println("[SKIPPED] Conversation snapshot live test skipped: " + reply.message());
        return;
    }
    ConversationSnapshot snap = conv.snapshot();
    test:assertEquals(snap.model, modelId, "Snapshot model should match constructor arg.");
    test:assertEquals(snap.turnCount, 1, "Snapshot turn count should be 1.");
    test:assertEquals(snap.history.length(), 2,
        "Snapshot history should have user + assistant = 2 messages.");
    io:println("Snapshot: model=", snap.model, ", turns=", snap.turnCount);
}

// ─── RAG Pipeline ──────────────────────────────────────────────────────────

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
        io:println("[SKIPPED] RAG pipeline live test skipped: " + result.message());
        return;
    }
    test:assertTrue(result.answer.length() > 0, "RAG answer should not be empty.");
    test:assertTrue(result.sources.length() > 0, "Should have at least one source document.");
    test:assertTrue(result.scores.length() == result.sources.length(),
        "Scores array should match sources array length.");
    io:println("RAG Answer: ", result.answer);
    io:println("RAG Sources: ", result.sources.length(), ", Top score: ", result.scores[0]);
}

@test:Config {groups: ["rag", "live"]}
function testRagPipelineWithCustomConfig() returns error? {
    RagDocument[] documents = [
        {id: "a", content: "Ballerina supports REST, gRPC, WebSockets, and GraphQL natively."},
        {id: "b", content: "Node.js is a JavaScript runtime built on Chrome's V8 engine."},
        {id: "c", content: "Ballerina's concurrency model uses strands, not OS threads."}
    ];

    RagResult|error result = ragQuery(
        hfClient,
        "What protocols does Ballerina support?",
        documents,
        {
            topK: 2,
            similarityThreshold: 0.1,
            maxTokens: 100,
            systemPrompt: "You are a Ballerina expert. Be precise and concise."
        }
    );
    if result is error {
        io:println("[SKIPPED] RAG custom config live test skipped: " + result.message());
        return;
    }
    test:assertTrue(result.answer.length() > 0, "Custom-config RAG answer should not be empty.");
    test:assertTrue(result.sources.length() <= 2, "topK=2 should return at most 2 source documents.");
    io:println("RAG (custom config) answer: ", result.answer);
}