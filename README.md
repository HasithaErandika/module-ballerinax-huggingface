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
3. Click **New token**, choose **Fine-grained**, and enable the **Inference Providers** permission. Copy this token.
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

configurable string? token = os:getEnv("HF_TOKEN");

public function main() returns error? {
    if token is string {
        huggingface:Client hf = check new ({auth: {token}});

        huggingface:ChatCompletionResponse chat = check hf->/v1/chat/completions.post({
            model: "meta-llama/Llama-3.2-3B-Instruct",
            messages: [{role: "user", content: "What is Ballerina API integration?"}],
            maxTokens: 100
        });
        
        io:println("Response: ", chat?.choices);
    } else {
        io:println("HF_TOKEN is not set; configure it in the environment or Config.toml.");
    }
}
```

> **Note on models and testing**
>
> The examples and tests in this repository use representative, publicly listed models such as `meta-llama/Llama-3.2-3B-Instruct`, `gpt2`, `distilbert-base-uncased-finetuned-sst-2-english`, `facebook/bart-large-cnn`, `Helsinki-NLP/opus-mt-en-fr`, `facebook/bart-large-mnli`, and others.  
> These are **examples only**: whether they work for you depends on your Hugging Face token’s permissions and Inference Providers configuration. If a test or example fails with a “model_not_supported” or 404 error, switch to another model ID that supports the same task and is available for your account.

## Examples

The `avi0ra/huggingface` connector provides practical examples illustrating usage in various scenarios. Explore these [examples](https://github.com/HasithaErandika/module-ballerinax-huggingface/tree/main/examples), covering the following use cases:

- [Chat & Text Generation](https://github.com/HasithaErandika/module-ballerinax-huggingface/tree/main/examples/text-generation) - LLM chat and raw text generation
- [Text Classification & NER](https://github.com/HasithaErandika/module-ballerinax-huggingface/tree/main/examples/text-classification) - Sentiment analysis and named entity recognition
- [Image Generation](https://github.com/HasithaErandika/module-ballerinax-huggingface/tree/main/examples/image-generation) - Text-to-image with FLUX developer models

## Build from the source

### Setting up the prerequisites

1. Download and install Java SE Development Kit (JDK) version 21. You can download it from either of the following sources:
    * [Oracle JDK](https://www.oracle.com/java/technologies/downloads/)
    * [OpenJDK](https://adoptium.net/)

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

## Contribute to Ballerina

As an open-source project, Ballerina welcomes contributions from the community.

For more information, go to the [contribution guidelines](https://github.com/ballerina-platform/ballerina-lang/blob/master/CONTRIBUTING.md).

## Code of conduct

All the contributors are encouraged to read the [Ballerina Code of Conduct](https://ballerina.io/code-of-conduct).

## Useful links

* For more information go to the [`huggingface` package](https://central.ballerina.io/avi0ra/huggingface/latest).
* For example demonstrations of the usage, go to [Ballerina By Examples](https://ballerina.io/learn/by-example/).
* Chat live with us via our [Discord server](https://discord.gg/ballerinalang).
* Post all technical questions on Stack Overflow with the [#ballerina](https://stackoverflow.com/questions/tagged/ballerina) tag.
