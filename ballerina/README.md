# Ballerina HuggingFace Connector

[![Build](https://github.com/HasithaErandika/module-ballerinax-huggingface/actions/workflows/ci.yml/badge.svg)](https://github.com/HasithaErandika/module-ballerinax-huggingface/actions/workflows/ci.yml)
[![GitHub Last Commit](https://img.shields.io/github/last-commit/HasithaErandika/module-ballerinax-huggingface.svg)](https://github.com/HasithaErandika/module-ballerinax-huggingface/commits/main)
[![GitHub Issues](https://img.shields.io/github/issues/HasithaErandika/module-ballerinax-huggingface.svg?label=Open%20Issues)](https://github.com/HasithaErandika/module-ballerinax-huggingface/issues)

## Overview

The `avi0ra/huggingface` Ballerina connector provides access to the [Hugging Face Inference API](https://huggingface.co/docs/api-inference/index), enabling Ballerina applications to run AI/ML models directly.

Supported capabilities include:
- Generative AI (Chat Completions via LLMs like Llama, DeepSeek)
- Text and Token Classification (Sentiment Analysis, Named Entity Recognition)
- Embeddings and Feature Extraction
- Media Generation (Text-to-Image via FLUX/Stable Diffusion)
- NLP Tasks (Summarization, Question Answering, Translation, Zero-Shot Classification)
- Audio and Vision Tasks (Automatic Speech Recognition, Image Classification)

## Setup guide

1. Create a free account at [Hugging Face](https://huggingface.co/join).
2. Go to your [Access Tokens page](https://huggingface.co/settings/tokens).

   ![Hugging Face access tokens page](https://raw.githubusercontent.com/HasithaErandika/module-ballerinax-huggingface/main/docs/setup-huggingface/get-token.png)

3. Click **New token**, choose **Fine-grained**, and enable the **Inference Providers** permission. Copy this token.

   ![Create fine-grained token with Inference Providers permission](https://raw.githubusercontent.com/HasithaErandika/module-ballerinax-huggingface/main/docs/setup-huggingface/type_fine-grained.png)

   or else, choose **Type == Read**

   ![Create read token with Inference Providers permission](https://raw.githubusercontent.com/HasithaErandika/module-ballerinax-huggingface/main/docs/setup-huggingface/type_read.png)


4. Add the connector to your Ballerina project:
   ```bash
   bal add avi0ra/huggingface
   ```
5. Configure the token in your generic `Config.toml` or environment variables, for example:
   ```toml
   HF_TOKEN = "<YOUR_HF_TOKEN>"
   ```

## Quickstart

This example shows how to use the connector for a simple Chat Completion request using an LLM.

```ballerina
import ballerina/io;
import ballerina/os;
import avi0ra/huggingface;

configurable string token = os:getEnv("HF_TOKEN");

public function main() returns error? {
    huggingface:Client hf = check new ({auth: {token}});

    huggingface:ChatCompletionResponse chat = check hf->/v1/chat/completions.post({
        model: "meta-llama/Llama-3.2-3B-Instruct",
        messages: [{role: "user", content: "What is Ballerina API integration?"}],
        maxTokens: 100
    });
    
    io:println("Response: ", chat?.choices);
}
```

### Generic inference (any model/task)

If you want to call *any* Hugging Face model (not just the typed helper methods), you can use the generic helper `inferModel`:

```ballerina
import ballerina/io;
import ballerina/os;
import avi0ra/huggingface;

configurable string token = os:getEnv("HF_TOKEN");

public function main() returns error? {
    huggingface:Client hf = check new ({auth: {token}});

    json result = check huggingface:inferModel(
        hf,
        "openai-community/gpt2",
        {inputs: "Ballerina is a modern language"}
    );

    io:println(result);
}
```

## Using Custom Models

The connector works with any model available on the Hugging Face Hub. Simply pass the model ID to the relevant function.

Any model ID can be used as long as it matches the task type. For example, for translation:

```ballerina
// Using a specific translation model
var result = hf->/hf\-inference/models/["Helsinki-NLP/opus-mt-en-si"].post({
    inputs: "Hello, how are you?"
});

// Or using a completely different one
var result = hf->/hf\-inference/models/["facebook/nllb-200-distilled-600M"].post({
    inputs: "Hello, how are you?"
});
```

### The only rules to follow

| Rule | Example |
|---|---|
| **Match the task** | Don't call a translation model with image classification |
| **Inference API support** | Check if the model has the "Inference API" badge on its HF page |
| **Access permissions** | Ensure the model is public or you have accepted gated access |

### How to find compatible models

You can browse models by task (pipeline tag) on Hugging Face:
- [Translation Models](https://huggingface.co/models?inference_provider=hf-inference&pipeline_tag=translation)
- [Text Classification Models](https://huggingface.co/models?inference_provider=hf-inference&pipeline_tag=text-classification)
- [Summarization Models](https://huggingface.co/models?inference_provider=hf-inference&pipeline_tag=summarization)

Just change the `pipeline_tag` value in the URL to any supported task (e.g., `text-generation`, `image-classification`, `automatic-speech-recognition`).

## Supported AI Tasks & Examples

The connector supports 12 distinct AI capabilities. Below are code snippets for each task using the generated client. Click to expand each example.

<details>
<summary>Chat Completion & Text Generation</summary>

Generate conversational responses or complete text using large language models.

```ballerina
huggingface:ChatCompletionResponse chat = check hf->/v1/chat/completions.post({
    model: "katanemo/Arch-Router-1.5B:hf-inference",
    messages: [{role: "user", content: "Say hello in one word."}],
    maxTokens: 10
});
io:println("Chat: ", chat?.choices);
```
**Sample Output:**
```json
[{"finishReason":"stop","index":0,"message":{"role":"assistant","content":"Hello"}}]
```
</details>

<details>
<summary>Text Classification (Sentiment Analysis)</summary>

Classify text into categories or determine sentiment.

```ballerina
huggingface:ClassificationLabel[][] res = check hf->/hf\-inference/models/["BAAI/bge-reranker-v2-m3"]/text\-classification.post({
    inputs: "Ballerina makes integration elegant!"
});
io:println("Sentiment: ", res[0][0]?.label, " (", res[0][0]?.score, ")");
```
**Sample Output:** `Sentiment: LABEL_0 (2.527748E-4)`
</details>

<details>
<summary>Token Classification (NER)</summary>

Extract entities like persons, locations, or organizations from text.

```ballerina
huggingface:TokenClassificationEntity[] entities = check hf->/hf\-inference/models/["dslim/bert-base-NER"]/token\-classification.post({
    inputs: "Someone is working at WSO2 in Sri Lanka."
});
io:println("NER: ", entities);
```
**Sample Output:**
```json
[{"entityGroup":"MISC","word":"WSO2","score":0.68191385},{"entityGroup":"LOC","word":"Sri Lanka","score":0.999514}]
```
</details>

<details>
<summary>Feature Extraction (Embeddings)</summary>

Generate embeddings for text, useful for semantic search and vector databases.

```ballerina
float[] embeddings = check hf->/hf\-inference/models/["intfloat/multilingual-e5-large"]/feature\-extraction.post({
    inputs: "Ballerina cloud-native integration."
});
io:println("Embedding size: ", embeddings.length());
```
**Sample Output:** `Embedding size: 1024`
</details>

<details>
<summary>Question Answering</summary>

Extract answers to questions based on a given context.

```ballerina
huggingface:QuestionAnsweringResponse ans = check hf->/hf\-inference/models/["deepset/roberta-base-squad2"]/question\-answering.post({
    inputs: {
        question: "What is Ballerina?", 
        context: "Ballerina is an open-source language for cloud-native integration by WSO2."
    }
});
io:println("Answer: ", ans?.answer);
```
**Sample Output:** `Answer: an open-source language for cloud-native integration by WSO2`
</details>

<details>
<summary>Summarization</summary>

Condense long text into a shorter summary.

```ballerina
huggingface:SummarizationResult[] res = check hf->/hf\-inference/models/["facebook/bart-large-cnn"]/summarization.post({
    inputs: "Ballerina is a modern open-source programming language designed for cloud-native integration. It was created by WSO2 and features built-in concurrency, network abstractions, and a rich type system ideal for microservices.",
    parameters: {maxLength: 40, minLength: 15}
});
io:println("Summary: ", res[0].summaryText);
```
**Sample Output:** `Summary: Ballerina is a modern open-source programming language designed for cloud-native integration...`
</details>

<details>
<summary>Translation</summary>

Translate text from one language to another.

```ballerina
huggingface:TranslationResult[] res = check hf->/hf\-inference/models/["Helsinki-NLP/opus-mt-en-fr"]/translation.post({
    inputs: "Hello, how are you?"
});
io:println("Translation: ", res[0].translationText);
```
**Sample Output:** `Translation: Bonjour, comment allez-vous ?`
</details>

<details>
<summary>Zero-Shot Classification</summary>

Classify text without specific training data by providing possible labels.

```ballerina
huggingface:ZeroShotClassificationResponse res = check hf->/hf\-inference/models/["facebook/bart-large-mnli"]/zero\-shot\-classification.post({
    inputs: "Ballerina is a programming language for cloud integration.",
    parameters: {candidateLabels: ["technology", "sports", "politics"]}
});
io:println("ZeroShot result: ", res);
```
**Sample Output:** 
```json
[{"label":"technology","score":0.96358},{"label":"sports","score":0.03109}]
```
</details>

<details>
<summary>Text-to-Image Generation</summary>

Generate images from text prompts.

```ballerina
byte[] imageBytes = check hf->/hf\-inference/models/["stabilityai/stable-diffusion-xl-base-1.0"]/text\-to\-image.post({
    inputs: "A Ballerina robot hacking on code",
    parameters: {width: 512, height: 512, numInferenceSteps: 4}
});
io:println("Generated image bytes: ", imageBytes.length());
```
**Sample Output:** `Generated image bytes: 51293`
</details>

<details>
<summary>Image Classification</summary>

Classify an image into categories.

```ballerina
byte[] payload = check io:fileReadBytes("test.jpg");
huggingface:ImageClassificationResult[] res = check hf->/hf\-inference/models/["google/vit-base-patch16-224"]/image\-classification.post(payload);
io:println("Image classifications: ", res);
```
**Sample Output:**
```json
[{"score":0.491866,"label":"toy terrier"},{"score":0.186933,"label":"wire-haired fox terrier"}]
```
</details>

<details>
<summary>Automatic Speech Recognition (ASR)</summary>

Transcribe audio into text.

```ballerina
byte[] payload = check io:fileReadBytes("test.wav");
huggingface:AutomaticSpeechRecognitionResponse res = check hf->/hf\-inference/models/["openai/whisper-large-v3-turbo"]/automatic\-speech\-recognition.post(payload);
io:println("ASR text: ", res?.text);
```
**Sample Output:** `ASR text: I have a dream that one day this nation will rise up...`
</details>
