# Ballerina HuggingFace Connector

[![Build](https://github.com/HasithaErandika/module-ballerinax-huggingface/actions/workflows/ci.yml/badge.svg)](https://github.com/HasithaErandika/module-ballerinax-huggingface/actions/workflows/ci.yml)
[![GitHub Last Commit](https://img.shields.io/github/last-commit/HasithaErandika/module-ballerinax-huggingface.svg)](https://github.com/HasithaErandika/module-ballerinax-huggingface/commits/main)
[![GitHub Issues](https://img.shields.io/github/issues/HasithaErandika/module-ballerinax-huggingface.svg?label=Open%20Issues)](https://github.com/HasithaErandika/module-ballerinax-huggingface/issues)

## Overview

The `avi0ra/huggingface` Ballerina connector provides access to the [Hugging Face Inference API](https://huggingface.co/docs/api-inference/index), enabling Ballerina applications to run state-of-the-art machine learning models directly.

Supported capabilities include:
- **Generative AI** — Chat Completions, Stateful Conversations, and Streaming Chat via LLMs
- **RAG Pipeline** — Built-in Retrieval-Augmented Generation with batch embeddings and similarity search
- **Text & Token Classification** — Sentiment Analysis, Named Entity Recognition
- **Embeddings & Feature Extraction** — Vector generation for semantic search
- **Media Generation** — Text-to-Image via FLUX / Stable Diffusion
- **NLP Tasks** — Summarization, Question Answering, Translation, Zero-Shot Classification
- **Audio & Vision** — Automatic Speech Recognition, Image Classification (from bytes, file, or URL)
- **Auto-Retry** — Exponential backoff for cold-starting models (HTTP 503)
- **Generic Inference & Metadata** — `inferModel`, `batchInfer`, `getModelInfo`

## Setup guide

1. Create a free account at [Hugging Face](https://huggingface.co/join).
2. Go to your [Access Tokens page](https://huggingface.co/settings/tokens).

   ![Hugging Face access tokens page](https://raw.githubusercontent.com/HasithaErandika/module-ballerinax-huggingface/main/docs/setup-huggingface/get-token.png)

3. Click **New token**, choose **Fine-grained**, and enable the **Inference Providers** permission. Copy this token.

   ![Create fine-grained token](https://raw.githubusercontent.com/HasithaErandika/module-ballerinax-huggingface/main/docs/setup-huggingface/type_fine-grained.png)

   or else, choose **Type == Read**

   ![Create read token](https://raw.githubusercontent.com/HasithaErandika/module-ballerinax-huggingface/main/docs/setup-huggingface/type_read.png)

4. Add the connector to your Ballerina project:
   ```bash
   bal pull avi0ra/huggingface
   ```
5. Configure the token in `Config.toml` or environment variables:
   ```toml
   token = "<YOUR_HF_TOKEN>"
   ```
   ```bash
   export HF_TOKEN="<YOUR_HF_TOKEN>"
   ```

## Quickstart

### Chat Completion

```ballerina
import ballerina/io;
import ballerina/os;
import avi0ra/huggingface;

configurable string token = os:getEnv("HF_TOKEN");

public function main() returns error? {
    huggingface:Client hf = check new ({auth: {token}});

    huggingface:ChatCompletionResponse resp = check hf->/v1/chat/completions.post({
        model: "katanemo/Arch-Router-1.5B:hf-inference",
        messages: [{role: "user", content: "What is Ballerina?"}],
        maxTokens: 100
    });

    io:println(resp?.choices);
}
```

### Streaming Chat Completion

Tokens arrive in real time as the model generates them:

```ballerina
import ballerina/io;
import ballerina/os;
import avi0ra/huggingface;

configurable string token = os:getEnv("HF_TOKEN");

public function main() returns error? {
    huggingface:Client hf = check new ({auth: {token}});

    stream<huggingface:ChatCompletionChunk, error?> tokenStream =
        check hf->/v1/chat/completions/streamed.post({
            model: "katanemo/Arch-Router-1.5B:hf-inference",
            messages: [{role: "user", content: "Count from 1 to 5."}],
            maxTokens: 50
        });

    check from huggingface:ChatCompletionChunk chunk in tokenStream do {
        huggingface:ChatCompletionChunkChoice[]? choices = chunk?.choices;
        if choices is huggingface:ChatCompletionChunkChoice[] && choices.length() > 0 {
            string? content = choices[0].delta?.content;
            if content is string {
                io:print(content);
            }
        }
    };
    io:println();
}
```

### Stateful Chat Conversation

Maintain cross-turn chat history automatically using the `Conversation` class:
```ballerina
import ballerina/io;
import ballerina/os;
import avi0ra/huggingface;

configurable string token = os:getEnv("HF_TOKEN");

public function main() returns error? {
    huggingface:Client hf = check new ({auth: {token}});

    huggingface:Conversation conv = new (
        hf,
        "katanemo/Arch-Router-1.5B:hf-inference",
        systemPrompt = "You are a helpful assistant."
    );

    string reply1 = check conv.chat("What is Ballerina?");
    io:println("Assistant: ", reply1);

    string reply2 = check conv.chat("Who created it?");
    io:println("Assistant: ", reply2);

    io:println("Turns completed: ", conv.turnCount());
}
```

### RAG Pipeline

End-to-end Retrieval Augmented Generation in a single function call:

```ballerina
import ballerina/io;
import ballerina/os;
import avi0ra/huggingface;

configurable string token = os:getEnv("HF_TOKEN");

public function main() returns error? {
    huggingface:Client hf = check new ({auth: {token}});

    huggingface:RagDocument[] documents = [
        {
            id: "doc1",
            content: "Ballerina is an open-source language for cloud-native integration by WSO2.",
            metadata: {"source": "ballerina.io"}
        },
        {
            id: "doc2",
            content: "WSO2 is a Sri Lankan technology company founded in 2005.",
            metadata: {"source": "wso2.com"}
        }
    ];

    huggingface:RagResult result = check huggingface:ragQuery(
        hf,
        "Who created Ballerina?",
        documents
    );

    io:println("Answer: ", result.answer);
    io:println("Sources used: ", result.sources.length());
    io:println("Top relevance score: ", result.scores[0]);
}
```

### Auto-Retry for Cold Models

Models on the free tier go cold after inactivity and return 503 while loading. The connector retries automatically with exponential backoff:

```ballerina
huggingface:Client hf = check new (
    {auth: {token}},
    retryConfig = {
        maxRetries: 5,
        initialDelay: 2.0,
        maxDelay: 30.0
    }
);
```

### Generic Inference & Metadata

Call any Hugging Face model not covered by the typed operations, or fetch metadata:

```ballerina
// Generic Inference
json result = check huggingface:inferModel(
    hf,
    "openai-community/gpt2",
    {inputs: "Ballerina is a modern language"}
);
io:println(result);

// Batch Inference
json[] batchResults = check huggingface:batchInfer(hf, ["Hello", "World"], "gpt2");

// Model Metadata Verification
huggingface:ModelAvailability available = check huggingface:checkModelAvailability(hf, "gpt2");
io:println("Available for Inference API: ", available.available);
```

## Using Custom Models

The connector works with any model available on the Hugging Face Hub. Simply pass the model ID to the relevant function.

```ballerina
// Any translation model works
check hf->/hf\-inference/models/["Helsinki-NLP/opus-mt-en-si"]/translation.post({
    inputs: "Hello, how are you?"
});
```

### Rules to follow

| Rule                      | Example                                                         |
| ------------------------- | --------------------------------------------------------------- |
| **Match the task**        | Don't call a translation model with image classification        |
| **Inference API support** | Check if the model has the "Inference API" badge on its HF page |
| **Access permissions**    | Ensure the model is public or you have accepted gated access    |

### How to find compatible models

Browse models by task on Hugging Face:
- [Translation Models](https://huggingface.co/models?inference_provider=hf-inference&pipeline_tag=translation)
- [Text Classification Models](https://huggingface.co/models?inference_provider=hf-inference&pipeline_tag=text-classification)
- [Summarization Models](https://huggingface.co/models?inference_provider=hf-inference&pipeline_tag=summarization)

Just change the `pipeline_tag` value in the URL to any supported task.

## Supported AI Tasks & Examples

The connector supports 13+ distinct AI capabilities. Click to expand each example.

<details>
<summary>Chat Completion & Text Generation</summary>

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
[
  {
    "finishReason": "stop",
    "index": 0,
    "message": { "role": "assistant", "content": "Hello" }
  }
]
```

</details>

<details>
<summary>Text Classification (Sentiment Analysis)</summary>

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

```ballerina
huggingface:TokenClassificationEntity[] entities = check hf->/hf\-inference/models/["dslim/bert-base-NER"]/token\-classification.post({
    inputs: "Someone is working at WSO2 in Sri Lanka."
});
io:println("NER: ", entities);
```

**Sample Output:**

```json
[
  { "entityGroup": "MISC", "word": "WSO2", "score": 0.68191385 },
  { "entityGroup": "LOC", "word": "Sri Lanka", "score": 0.999514 }
]
```

</details>

<details>
<summary>Feature Extraction (Embeddings)</summary>

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

```ballerina
huggingface:QuestionAnsweringResponse ans = check hf->/hf\-inference/models/["deepset/roberta-base-squad2"]/question\-answering.post({
    inputs: {
        question: "What is Ballerina?",
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

```ballerina
huggingface:SummarizationResult[] res = check hf->/hf\-inference/models/["facebook/bart-large-cnn"]/summarization.post({
    inputs: "Ballerina is a modern open-source programming language designed for cloud-native integration. It was created by WSO2 and features built-in concurrency, network abstractions, and a rich type system ideal for microservices.",
    parameters: {maxLength: 40, minLength: 15}
});
io:println("Summary: ", res[0].summaryText);
```
</details>

<details>
<summary>Translation</summary>

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

```ballerina
huggingface:ZeroShotClassificationResponse res = check hf->/hf\-inference/models/["facebook/bart-large-mnli"]/zero\-shot\-classification.post({
    inputs: "Ballerina is a programming language for cloud integration.",
    parameters: {candidateLabels: ["technology", "sports", "politics"]}
});
io:println("ZeroShot result: ", res);
```

</details>

<details>
<summary>Text-to-Image Generation</summary>

```ballerina
byte[] imageBytes = check hf->/hf\-inference/models/["stabilityai/stable-diffusion-xl-base-1.0"]/text\-to\-image.post({
    inputs: "A Ballerina robot hacking on code",
    parameters: {width: 512, height: 512, numInferenceSteps: 4}
});
io:println("Generated image bytes: ", imageBytes.length());
```
</details>

<details>
<summary>Image Classification (bytes, file, URL)</summary>

```ballerina
// From raw bytes
byte[] payload = check io:fileReadBytes("test.jpg");
huggingface:ImageClassificationResult[] res = check hf->/hf\-inference/models/["google/vit-base-patch16-224"]/image\-classification.post(payload);

// From file path
huggingface:ImageClassificationResult[] res = check hf->/hf\-inference/models/["google/vit-base-patch16-224"]/image\-classification/file.post("image.jpg");

// From URL
huggingface:ImageClassificationResult[] res = check hf->/hf\-inference/models/["google/vit-base-patch16-224"]/image\-classification/url.post("https://example.com/image.jpg");

io:println("Image classifications: ", res);
```

</details>

<details>
<summary>Automatic Speech Recognition (bytes, file, URL)</summary>

```ballerina
// From raw bytes
byte[] payload = check io:fileReadBytes("test.wav");
huggingface:AutomaticSpeechRecognitionResponse res = check hf->/hf\-inference/models/["openai/whisper-large-v3-turbo"]/automatic\-speech\-recognition.post(payload);

// From file path
huggingface:AutomaticSpeechRecognitionResponse res = check hf->/hf\-inference/models/["openai/whisper-large-v3-turbo"]/automatic\-speech\-recognition/file.post("audio.flac");

io:println("ASR text: ", res?.text);
```
</details>

## Build from the source

### Setting up the prerequisites

1. Download and install Java SE Development Kit (JDK) version 21. You can download it from either of the following sources:
   - [Oracle JDK](https://www.oracle.com/java/technologies/downloads/)
   - [OpenJDK](https://adoptium.net/)

   > **Note:** After installation, remember to set the `JAVA_HOME` environment variable to the directory where JDK was installed.

2. Download and install [Ballerina Swan Lake](https://ballerina.io/).

3. Download and install [Docker](https://www.docker.com/get-started).

   > **Note**: Ensure that the Docker daemon is running before executing any tests.

4. Export Github Personal access token with read package permissions as follows,
   ```bash
   export packageUser=<Username>
   export packagePAT=<Personal access token>
   ```

### Build options

Execute the commands below to build from the source.

1. To build the package:

   ```bash
   ./gradlew clean build
   ```

2. To run the tests:

   ```bash
   ./gradlew clean test
   ```

3. To build the without the tests:

   ```bash
   ./gradlew clean build -x test
   ```

4. To run tests against different environments:

   ```bash
   ./gradlew clean test -Pgroups=<Comma separated groups/test cases>
   ```

5. To debug the package with a remote debugger:

   ```bash
   ./gradlew clean build -Pdebug=<port>
   ```

6. To debug with the Ballerina language:

   ```bash
   ./gradlew clean build -PbalJavaDebug=<port>
   ```

7. Publish the generated artifacts to the local Ballerina Central repository:

   ```bash
   ./gradlew clean build -PpublishToLocalCentral=true
   ```

8. Publish the generated artifacts to the Ballerina Central repository:
   ```bash
   ./gradlew clean build -PpublishToCentral=true
   ```

## Changelog

### 1.0.0
- Added stateful `Conversation` class for automated chat history management.
- Added batch inference operations (`batchInfer` and typed`/batch` endpoints).
- Added Model Metadata APIs (`getModelInfo`, `checkModelAvailability`).
- Upgraded `ragQuery` to use batch embeddings and `RagConfig`.

### 0.3.0
- Added streaming chat completions via `/v1/chat/completions/streamed`.
- Added RAG pipeline helper `ragQuery` (initial version).
- Added automatic retry with exponential backoff for cold-starting models (503).
- Added image classification from file path and URL.
- Added ASR from file path and URL.
- Introduced `RetryConfig`, `RagDocument`, `RagResult`, `ImageContentType`, `AudioContentType` types.
- Improved generic `inferModel` helper with rich error handling.

### 0.2.0
- Initial release of the `avi0ra/huggingface` connector.
- Native support for 12 AI/ML inference operations.
- Generic `inferModel` helper.

## Contribute to Ballerina

As an open-source project, Ballerina welcomes contributions from the community.

For more information, go to the [contribution guidelines](https://github.com/ballerina-platform/ballerina-lang/blob/master/CONTRIBUTING.md).

## Code of conduct

All the contributors are encouraged to read the [Ballerina Code of Conduct](https://ballerina.io/code-of-conduct).

## Useful links

- For more information go to the [`huggingface` package](https://central.ballerina.io/avi0ra/huggingface/latest).
- For example demonstrations of the usage, go to [Ballerina By Examples](https://ballerina.io/learn/by-example/).
- Chat live with us via our [Discord server](https://discord.gg/ballerinalang).
- Post all technical questions on Stack Overflow with the [#ballerina](https://stackoverflow.com/questions/tagged/ballerina) tag.
