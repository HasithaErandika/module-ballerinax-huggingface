Connects Ballerina applications to the [Hugging Face Hub](https://huggingface.co/docs/api-inference/index) Inference API for running state-of-the-art machine learning models.

This package provides a `Client` generated from the Hugging Face OpenAPI definition and exposes resources for common tasks such as:

- Chat completions
- Text generation
- Text and token classification
- Summarization and translation
- Embeddings (feature extraction)
- Image classification
- Automatic speech recognition

### Configure the connector

The connector authenticates with the Hugging Face Hub using a bearer token.

You can provide this token as an environment variable:

- **Environment variable**: `HF_TOKEN`

Or via the `ConnectionConfig` record when constructing the client.

```ballerina
import ballerinax/huggingface;
import ballerina/os;

configurable string token = os:getEnv("HF_TOKEN");

public function initHuggingFaceClient() returns huggingface:Client|error {
    huggingface:ConnectionConfig config = {
        auth: {
            token: token
        }
    };

    return new (config);
}
```

### Basic usage

#### Chat completions

```ballerina
import ballerinax/huggingface;
import ballerina/os;

configurable string token = os:getEnv("HF_TOKEN");

public function main() returns error? {
    huggingface:Client hfClient = check new ({auth: {token}});

    huggingface:ChatCompletionResponse resp = check hfClient->/v1/chat/completions.post({
        model: "meta-llama/Llama-3.2-3B-Instruct",
        messages: [
            {role: "user", content: "Say hello in one sentence."}
        ],
        maxTokens: 32
    });

    if resp?.choices is huggingface:ChatCompletionChoice[] {
        io:println(resp.choices[0].message?.content);
    }
}
```

#### Text generation

```ballerina
import ballerinax/huggingface;
import ballerina/os;

configurable string token = os:getEnv("HF_TOKEN");

public function main() returns error? {
    huggingface:Client hfClient = check new ({auth: {token}});

    huggingface:TextGenerationResult[] res = check hfClient->/models/["gpt2"].post({
        inputs: "Ballerina is designed for",
        parameters: {
            maxNewTokens: 20,
            returnFullText: false
        }
    });

    if res.length() > 0 {
        io:println(res[0].generatedText);
    }
}
```

