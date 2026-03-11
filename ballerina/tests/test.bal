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
    ChatCompletionResponse resp = check hfClient->/v1/chat/completions.post({
        model: "meta-llama/Llama-3.2-3B-Instruct",
        messages: [{role: "user", content: "Say hello in one word."}],
        maxTokens: 10
    });
    test:assertTrue(resp?.choices is ChatCompletionChoice[]);
    io:println("Chat: ", resp?.choices);
}

@test:Config {groups: ["text-gen", "live"]}
function testTextGeneration() returns error? {
    TextGenerationResult[] res = check hfClient->/models/["gpt2"].post({
        inputs: "Ballerina is designed for",
        parameters: {maxNewTokens: 20, returnFullText: false}
    });
    test:assertTrue(res.length() > 0);
    io:println("Generated: ", res[0].generatedText);
}

@test:Config {groups: ["classification", "live"]}
function testTextClassification() returns error? {
    ClassificationLabel[][] res = check hfClient->/models/["distilbert-base-uncased-finetuned-sst-2-english"]/text\-classification.post({
        inputs: "Ballerina makes integration elegant!"
    });
    test:assertTrue(res.length() > 0);
    io:println("Sentiment: ", res[0][0]?.label, " (", res[0][0]?.score, ")");
}

@test:Config {groups: ["ner", "live"]}
function testTokenClassification() returns error? {
    TokenClassificationEntity[] entities = check hfClient->/models/["dbmdz/bert-large-cased-finetuned-conll03-english"]/token\-classification.post({
        inputs: "Hasitha Erandika works at WSO2 in Sri Lanka."
    });
    test:assertTrue(entities.length() > 0);
    io:println("NER: ", entities);
}

@test:Config {groups: ["embeddings", "live"]}
function testFeatureExtraction() returns error? {
    float[][] embeddings = check hfClient->/models/["sentence-transformers/all-MiniLM-L6-v2"]/feature\-extraction.post({
        inputs: "Ballerina cloud-native integration."
    });
    test:assertTrue(embeddings.length() > 0);
    io:println("Embedding size: ", embeddings.length());
}

@test:Config {groups: ["qa", "live"]}
function testQuestionAnswering() returns error? {
    QuestionAnsweringResponse ans = check hfClient->/models/["deepset/roberta-base-squad2"]/question\-answering.post({
        inputs: {question: "What is Ballerina?", context: "Ballerina is an open-source language for cloud-native integration by WSO2."}
    });
    test:assertTrue(ans?.answer is string);
    io:println("Answer: ", ans?.answer);
}

@test:Config {groups: ["summarization", "live"]}
function testSummarization() returns error? {
    SummarizationResult[] res = check hfClient->/models/["facebook/bart-large-cnn"]/summarization.post({
        inputs: "Ballerina is a modern open-source programming language designed for cloud-native integration. It was created by WSO2 and features built-in concurrency, network abstractions, and a rich type system ideal for microservices.",
        parameters: {maxLength: 40, minLength: 15}
    });
    test:assertTrue(res.length() > 0);
    io:println("Summary: ", res[0].summaryText);
}

@test:Config {groups: ["translation", "live"]}
function testTranslation() returns error? {
    TranslationResult[] res = check hfClient->/models/["Helsinki-NLP/opus-mt-en-fr"]/translation.post({
        inputs: "Hello, how are you?"
    });
    test:assertTrue(res.length() > 0);
    io:println("Translation: ", res[0].translationText);
}

@test:Config {groups: ["zero-shot", "live"]}
function testZeroShotClassification() returns error? {
    ZeroShotClassificationResponse resp = check hfClient->/models/["facebook/bart-large-mnli"]/zero\-shot\-classification.post({
        inputs: "Ballerina is a programming language for cloud integration.",
        parameters: {candidateLabels: ["technology", "sports", "politics"]}
    });
    test:assertTrue(resp?.labels is string[]);
    io:println("Labels: ", resp?.labels, " Scores: ", resp?.scores);
}
