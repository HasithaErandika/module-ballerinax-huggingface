# Examples

The `ballerinax/huggingface` connector provides practical examples illustrating usage in various scenarios.

These examples are organized as separate Ballerina packages under this `examples/` directory and are intended as small, focused applications:

1. **Chat & Text Generation** – Use LLMs for chat-style responses and free-form text completion.
2. **Text Classification & NER** – Run sentiment analysis and extract named entities from text.
3. **Image Generation** – Generate images from natural language prompts using text-to-image models.

Each example package contains:

- Its own `Ballerina.toml` file.
- A `main.bal` file demonstrating the use case.
- A `Config.toml` file describing the required configuration (such as the Hugging Face token).
- A `README.md` explaining the scenario and how to run it.

## Prerequisites

1. A Hugging Face account with an access token that has **Inference Providers** permissions.
2. Java 21 and Ballerina Swan Lake installed.
3. The `ballerinax/huggingface` module built or pulled from Ballerina Central.

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

