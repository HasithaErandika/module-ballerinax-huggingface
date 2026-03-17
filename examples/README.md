# Examples

The `avi0ra/huggingface` connector provides practical examples illustrating usage in various scenarios.

These examples are organized as separate Ballerina packages under this `examples/` directory and are intended as small, focused applications:

1. **Chat & Text Generation** – Use LLMs for chat-style responses and free-form text completion.
2. **Streaming Chat & RAG** – Stream tokens in real-time and build grounded answers using the built-in RAG pipeline.
3. **Text Classification & NER** – Run sentiment analysis and extract named entities from text.
4. **Image & Audio** – Generate images from text and run ASR/classification from URL, file, or bytes.

Each example package contains:

- Its own `Ballerina.toml` file.
- A `main.bal` file demonstrating the use case.
- A `Config.toml` file describing the required configuration (such as the Hugging Face token).
- A `README.md` explaining the scenario and how to run it.

## Prerequisites

1. A Hugging Face account with an access token that has **Inference Providers** permissions.
2. Java 21 and Ballerina Swan Lake installed.
3. The `avi0ra/huggingface` module built or pulled from Ballerina Central.

For each example, create a `Config.toml` file with the token, for example:

```toml
HF_TOKEN = "<YOUR_HF_TOKEN>"
```

## Running an example

From within an example package directory (for instance, `examples/text-generation`):

```bash
bal run
```

## Building the examples with the local module

To run all examples against your local changes to the connector, you can use the helper script from the `examples/` directory:

```bash
./build.sh build   # build all examples
./build.sh run     # run all examples
```

## Using Custom Models in Examples

While these examples use specific model IDs (like `Llama-3.2-3B-Instruct` or `gpt2`), you can modify the `main.bal` in any example to use **any** compatible model from the Hugging Face Hub.

Just ensure:
1. The model supports the task (e.g., don't use a translation model for image generation).
2. The model ID is passed correctly in the resource path (e.g., `hfClient->/hf\-inference/models/["your/model-id"].post(...)`).
3. You have the necessary permissions/access for that specific model.
