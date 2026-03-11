# Ballerina HuggingFace Connector

[![Build](https://github.com/HasithaErandika/module-ballerinax-huggingface/actions/workflows/ci.yml/badge.svg)](https://github.com/HasithaErandika/module-ballerinax-huggingface/actions/workflows/ci.yml)
[![GitHub Last Commit](https://img.shields.io/github/last-commit/HasithaErandika/module-ballerinax-huggingface.svg)](https://github.com/HasithaErandika/module-ballerinax-huggingface/commits/main)
[![GitHub Issues](https://img.shields.io/github/issues/HasithaErandika/module-ballerinax-huggingface.svg?label=Open%20Issues)](https://github.com/HasithaErandika/module-ballerinax-huggingface/issues)

## Overview

The `ballerinax/huggingface` Ballerina connector provides access to the [Hugging Face Inference API](https://huggingface.co/docs/api-inference/index), enabling Ballerina applications to run AI/ML models directly.

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
3. Click **New token**, choose **Fine-grained**, and enable the **Inference Providers** permission. Copy this token.
4. Add the connector to your Ballerina project:
   ```bash
   bal add ballerinax/huggingface
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
import ballerinax/huggingface;

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

## Examples

The `huggingface` connector provides practical examples illustrating usage in various scenarios. Explore these [examples](https://github.com/HasithaErandika/module-ballerinax-huggingface/tree/main/examples), covering the following use cases:

- [Chat & Text Generation](https://github.com/HasithaErandika/module-ballerinax-huggingface/tree/main/examples/text-generation) - LLM chat and raw text generation
- [Text Classification & NER](https://github.com/HasithaErandika/module-ballerinax-huggingface/tree/main/examples/text-classification) - Sentiment analysis and named entity recognition
- [Image Generation](https://github.com/HasithaErandika/module-ballerinax-huggingface/tree/main/examples/image-generation) - Text-to-image with FLUX developer models
