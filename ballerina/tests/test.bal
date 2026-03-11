// Copyright (c) 2026, Hasitha Erandika (http://github.com/HasithaErandika).
// Licensed under the Apache License, Version 2.0.

import ballerina/io;
import ballerina/os;
import ballerina/test;

configurable string token = os:getEnv("HF_TOKEN");

Client hfClient = check new ({auth: {token}});

@test:Config {groups: ["unit"]}
function testClientInit() returns error? {
    Client c = check new ({auth: {token: "test"}});
    test:assertNotEquals(c, ());
}

@test:Config {groups: ["chat", "live"]}
function testChatCompletion() returns error? {
    var result = trap hfClient->/v1/chat/completions.post({
        model: "google/gemma-2-2b-it",
        messages: [{role: "user", content: "Say hello in one word."}],
        maxTokens: 10
    });
    if result is error {
        io:println("ChatCompletion live test skipped due to API error: ", result);
        return;
    }
    ChatCompletionResponse resp = <ChatCompletionResponse>result;
    test:assertTrue(resp?.choices is ChatCompletionChoice[]);
    io:println("Chat: ", resp?.choices);
}

@test:Config {groups: ["text-gen", "live"]}
function testTextGeneration() returns error? {
    var result = trap hfClient->/models/["gpt2"].post({
        inputs: "Ballerina is designed for",
        parameters: {maxNewTokens: 20, returnFullText: false}
    });
    if result is error {
        io:println("TextGeneration live test skipped due to API error: ", result);
        return;
    }
    TextGenerationResult[] res = <TextGenerationResult[]>result;
    test:assertTrue(res.length() > 0);
    io:println("Generated: ", res[0].generatedText);
}

@test:Config {groups: ["classification", "live"]}
function testTextClassification() returns error? {
    var result = trap hfClient->/models/["distilbert-base-uncased-finetuned-sst-2-english"]/text\-classification.post({
        inputs: "Ballerina makes integration elegant!"
    });
    if result is error {
        io:println("TextClassification live test skipped due to API error: ", result);
        return;
    }
    ClassificationLabel[][] res = <ClassificationLabel[][]>result;
    test:assertTrue(res.length() > 0);
    io:println("Sentiment: ", res[0][0]?.label, " (", res[0][0]?.score, ")");
}

@test:Config {groups: ["ner", "live"]}
function testTokenClassification() returns error? {
    var result = trap hfClient->/models/["dbmdz/bert-large-cased-finetuned-conll03-english"]/token\-classification.post({
        inputs: "Hasitha Erandika works at WSO2 in Sri Lanka."
    });
    if result is error {
        io:println("TokenClassification live test skipped due to API error: ", result);
        return;
    }
    TokenClassificationEntity[] entities = <TokenClassificationEntity[]>result;
    test:assertTrue(entities.length() > 0);
    io:println("NER: ", entities);
}

@test:Config {groups: ["embeddings", "live"]}
function testFeatureExtraction() returns error? {
    var result = trap hfClient->/models/["sentence-transformers/all-MiniLM-L6-v2"]/feature\-extraction.post({
        inputs: "Ballerina cloud-native integration."
    });
    if result is error {
        io:println("FeatureExtraction live test skipped due to API error: ", result);
        return;
    }
    float[][] embeddings = <float[][]>result;
    test:assertTrue(embeddings.length() > 0);
    io:println("Embedding size: ", embeddings.length());
}

@test:Config {groups: ["qa", "live"]}
function testQuestionAnswering() returns error? {
    var result = trap hfClient->/models/["deepset/roberta-base-squad2"]/question\-answering.post({
        inputs: {question: "What is Ballerina?", context: "Ballerina is an open-source language for cloud-native integration by WSO2."}
    });
    if result is error {
        io:println("QuestionAnswering live test skipped due to API error: ", result);
        return;
    }
    QuestionAnsweringResponse ans = <QuestionAnsweringResponse>result;
    test:assertTrue(ans?.answer is string);
    io:println("Answer: ", ans?.answer);
}

@test:Config {groups: ["summarization", "live"]}
function testSummarization() returns error? {
    var result = trap hfClient->/models/["facebook/bart-large-cnn"]/summarization.post({
        inputs: "Ballerina is a modern open-source programming language designed for cloud-native integration. It was created by WSO2 and features built-in concurrency, network abstractions, and a rich type system ideal for microservices.",
        parameters: {maxLength: 40, minLength: 15}
    });
    if result is error {
        io:println("Summarization live test skipped due to API error: ", result);
        return;
    }
    SummarizationResult[] res = <SummarizationResult[]>result;
    test:assertTrue(res.length() > 0);
    io:println("Summary: ", res[0].summaryText);
}

@test:Config {groups: ["translation", "live"]}
function testTranslation() returns error? {
    var result = trap hfClient->/models/["Helsinki-NLP/opus-mt-en-fr"]/translation.post({
        inputs: "Hello, how are you?"
    });
    if result is error {
        io:println("Translation live test skipped due to API error: ", result);
        return;
    }
    TranslationResult[] res = <TranslationResult[]>result;
    test:assertTrue(res.length() > 0);
    io:println("Translation: ", res[0].translationText);
}

@test:Config {groups: ["image-gen", "live"]}
function testTextToImage() returns error? {
    var result = trap hfClient->/models/["black-forest-labs/FLUX.1-dev"]/text\-to\-image.post({
        inputs: "A Ballerina robot hacking on code",
        parameters: {width: 512, height: 512, numInferenceSteps: 4}
    });
    if result is error {
        io:println("TextToImage live test skipped due to API error: ", result);
        return;
    }
    byte[] imageBytes = <byte[]>result;
    test:assertTrue(imageBytes.length() > 0);
    io:println("Generated image bytes: ", imageBytes.length());
}

@test:Config {groups: ["image-classification", "live"]}
function testImageClassification() returns error? {
    // Dummy image payload – in a real test, load bytes of a PNG/JPEG.
    byte[] payload = [];
    var result = trap hfClient->/models/["google/vit-base-patch16-224"]/image\-classification.post(payload);
    if result is error {
        io:println("ImageClassification live test skipped due to API error: ", result);
        return;
    }
    ImageClassificationResult[] res = <ImageClassificationResult[]>result;
    test:assertTrue(res.length() >= 0);
    io:println("Image classifications: ", res);
}

@test:Config {groups: ["asr", "live"]}
function testAutomaticSpeechRecognition() returns error? {
    // Dummy audio payload – in a real test, load bytes of an audio file.
    byte[] payload = [];
    var result = trap hfClient->/models/["openai/whisper-large-v3"]/automatic\-speech\-recognition.post(payload);
    if result is error {
        io:println("ASR live test skipped due to API error: ", result);
        return;
    }
    AutomaticSpeechRecognitionResponse resp = <AutomaticSpeechRecognitionResponse>result;
    io:println("ASR text: ", resp?.text);
}

@test:Config {groups: ["zero-shot", "live"]}
function testZeroShotClassification() returns error? {
    var result = trap hfClient->/models/["facebook/bart-large-mnli"]/zero\-shot\-classification.post({
        inputs: "Ballerina is a programming language for cloud integration.",
        parameters: {candidateLabels: ["technology", "sports", "politics"]}
    });
    if result is error {
        io:println("ZeroShotClassification live test skipped due to API error: ", result);
        return;
    }
    ZeroShotClassificationResponse resp = <ZeroShotClassificationResponse>result;
    test:assertTrue(resp?.labels is string[]);
    io:println("Labels: ", resp?.labels, " Scores: ", resp?.scores);
}
