# Hugging Face Connector for Ballerina

Connects Ballerina applications to the [Hugging Face Inference API](https://huggingface.co/docs/api-inference/index)
for running state-of-the-art machine learning models hosted on the Hugging Face Hub.

This package provides a typed `Client` with strongly-typed request and response records
for 12 AI/ML tasks, a generic `inferModel` helper for any model, a built-in RAG pipeline,
streaming chat completions, automatic retry for cold-starting models, and multi-modal
helpers for loading images and audio from files or URLs.

---

## Supported AI Tasks

| Task | Resource Path | Example Model |
|---|---|---|
| Chat Completion | `/v1/chat/completions` | `katanemo/Arch-Router-1.5B:hf-inference` |
| Streaming Chat | `/v1/chat/completions/streamed` | `katanemo/Arch-Router-1.5B:hf-inference` |
| Text Generation | `/hf-inference/models/{model}` | `openai-community/gpt2` |
| Text Classification | `/hf-inference/models/{model}/text-classification` | `BAAI/bge-reranker-v2-m3` |
| Token Classification (NER) | `/hf-inference/models/{model}/token-classification` | `dslim/bert-base-NER` |
| Feature Extraction | `/hf-inference/models/{model}/feature-extraction` | `intfloat/multilingual-e5-large` |
| Question Answering | `/hf-inference/models/{model}/question-answering` | `deepset/roberta-base-squad2` |
| Summarization | `/hf-inference/models/{model}/summarization` | `facebook/bart-large-cnn` |
| Translation | `/hf-inference/models/{model}/translation` | `Helsinki-NLP/opus-mt-en-fr` |
| Zero-Shot Classification | `/hf-inference/models/{model}/zero-shot-classification` | `facebook/bart-large-mnli` |
| Text-to-Image | `/hf-inference/models/{model}/text-to-image` | `stabilityai/stable-diffusion-xl-base-1.0` |
| Image Classification | `/hf-inference/models/{model}/image-classification` | `google/vit-base-patch16-224` |
| Automatic Speech Recognition | `/hf-inference/models/{model}/automatic-speech-recognition` | `openai/whisper-large-v3-turbo` |

> Any model available on the Hugging Face Hub can be used — not just the examples above.
> Browse by task at [huggingface.co/models](https://huggingface.co/models?inference_provider=hf-inference).

---

## Setup

### 1. Get a Hugging Face token

1. Create a free account at [huggingface.co](https://huggingface.co/join)
2. Go to [Settings → Access Tokens](https://huggingface.co/settings/tokens)
3. Click **New token**, choose **Read** type, enable **Inference Providers** under the Inference section
4. Copy the token

### 2. Add the connector
```bash
bal add avi0ra/huggingface
```

### 3. Configure the token

In `Config.toml`:
```toml
token = "<YOUR_HF_TOKEN>"
```

Or via environment variable:
```bash
export HF_TOKEN="<YOUR_HF_TOKEN>"
```

---

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

Models on the free tier go cold after inactivity and return 503 while loading.
The connector retries automatically with exponential backoff:
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

### Multi-Modal Helpers

Load images and audio from files or URLs directly:
```ballerina
// Image from file
huggingface:ImageClassificationResult[] res =
    check hf->/hf\-inference/models/["google/vit-base-patch16-224"]/image\-classification/file.post(
        "path/to/image.jpg"
    );

// Image from URL
huggingface:ImageClassificationResult[] res =
    check hf->/hf\-inference/models/["google/vit-base-patch16-224"]/image\-classification/url.post(
        "https://example.com/image.jpg"
    );

// Audio from file
huggingface:AutomaticSpeechRecognitionResponse resp =
    check hf->/hf\-inference/models/["openai/whisper-large-v3-turbo"]/automatic\-speech\-recognition/file.post(
        "path/to/audio.flac"
    );
```

---

## All Supported Operations

<details>
<summary>Text Classification</summary>

```ballerina
huggingface:ClassificationLabel[][] res =
    check hf->/hf\-inference/models/["BAAI/bge-reranker-v2-m3"]/text\-classification.post({
        inputs: "Ballerina makes integration elegant!"
    });
io:println(res[0][0]?.label, " (", res[0][0]?.score, ")");
```
</details>

<details>
<summary>Token Classification (NER)</summary>

```ballerina
huggingface:TokenClassificationEntity[] entities =
    check hf->/hf\-inference/models/["dslim/bert-base-NER"]/token\-classification.post({
        inputs: "WSO2 is based in Sri Lanka."
    });
io:println(entities);
```
</details>

<details>
<summary>Feature Extraction (Embeddings)</summary>

```ballerina
float[] embeddings =
    check hf->/hf\-inference/models/["intfloat/multilingual-e5-large"]/feature\-extraction.post({
        inputs: "Ballerina cloud-native integration."
    });
io:println("Dimensions: ", embeddings.length());
```
</details>

<details>
<summary>Question Answering</summary>

```ballerina
huggingface:QuestionAnsweringResponse ans =
    check hf->/hf\-inference/models/["deepset/roberta-base-squad2"]/question\-answering.post({
        inputs: {
            question: "What is Ballerina?",
            context: "Ballerina is an open-source language for cloud-native integration by WSO2."
        }
    });
io:println(ans?.answer);
```
</details>

<details>
<summary>Summarization</summary>

```ballerina
huggingface:SummarizationResult[] res =
    check hf->/hf\-inference/models/["facebook/bart-large-cnn"]/summarization.post({
        inputs: "Ballerina is a modern open-source programming language designed for cloud-native integration...",
        parameters: {maxLength: 40, minLength: 15}
    });
io:println(res[0].summaryText);
```
</details>

<details>
<summary>Translation</summary>

```ballerina
huggingface:TranslationResult[] res =
    check hf->/hf\-inference/models/["Helsinki-NLP/opus-mt-en-fr"]/translation.post({
        inputs: "Hello, how are you?"
    });
io:println(res[0].translationText);
```
</details>

<details>
<summary>Zero-Shot Classification</summary>

```ballerina
huggingface:ZeroShotClassificationResponse res =
    check hf->/hf\-inference/models/["facebook/bart-large-mnli"]/zero\-shot\-classification.post({
        inputs: "Ballerina is a programming language for cloud integration.",
        parameters: {candidateLabels: ["technology", "sports", "politics"]}
    });
io:println(res);
```
</details>

<details>
<summary>Text-to-Image Generation</summary>

```ballerina
byte[] imageBytes =
    check hf->/hf\-inference/models/["stabilityai/stable-diffusion-xl-base-1.0"]/text\-to\-image.post({
        inputs: "A robot writing Ballerina code",
        parameters: {width: 512, height: 512, numInferenceSteps: 4}
    });
check io:fileWriteBytes("output.png", imageBytes);
```
</details>

<details>
<summary>Image Classification</summary>

```ballerina
byte[] payload = check io:fileReadBytes("image.jpg");
huggingface:ImageClassificationResult[] res =
    check hf->/hf\-inference/models/["google/vit-base-patch16-224"]/image\-classification.post(payload);
io:println(res[0]?.label, " (", res[0]?.score, ")");
```
</details>

<details>
<summary>Automatic Speech Recognition</summary>

```ballerina
huggingface:AutomaticSpeechRecognitionResponse resp =
    check hf->/hf\-inference/models/["openai/whisper-large-v3-turbo"]/automatic\-speech\-recognition/file.post(
        "audio.flac"
    );
io:println(resp?.text);
```
</details>

---

## Generic Inference Helper

Call any Hugging Face model not covered by the typed operations:
```ballerina
json result = check huggingface:inferModel(
    hf,
    "openai-community/gpt2",
    {inputs: "Ballerina is designed for"}
);
io:println(result);
```

---

## Using Custom Models

The connector works with any model on the Hugging Face Hub.
Pass any model ID as long as it matches the task:
```ballerina
check hf->/hf\-inference/models/["Helsinki-NLP/opus-mt-en-si"]/translation.post({
    inputs: "Hello"
});
```

Browse available models by task:
- [Translation](https://huggingface.co/models?pipeline_tag=translation&inference_provider=hf-inference)
- [Text Classification](https://huggingface.co/models?pipeline_tag=text-classification&inference_provider=hf-inference)

---

## Changelog

### 0.3.0
- Added streaming chat completions via `/v1/chat/completions/streamed`
- Added RAG pipeline helper `ragQuery`
- Added automatic retry with exponential backoff for cold-starting models (503)
- Added image classification from file path and URL
- Added ASR from file path and URL
- Introduced `RetryConfig`, `RagDocument`, `RagResult`, `ImageContentType`, `AudioContentType` types

### 0.2.x
- Initial 12 AI/ML operations
- Generic `inferModel` helper

---

## Issues and contributions

Report issues at [github.com/HasithaErandika/module-ballerinax-huggingface/issues](https://github.com/HasithaErandika/module-ballerinax-huggingface/issues).

For Ballerina community support: [Discord](https://discord.gg/ballerinalang) · [Stack Overflow #ballerina](https://stackoverflow.com/questions/tagged/ballerina)
