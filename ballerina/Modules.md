## Modules

### `huggingface`

The default module of this package, which provides:

- The `Client` for communicating with the Hugging Face Inference API.
- Configuration record `ConnectionConfig`.
- Record types for requests and responses for the supported operations (chat completions, text generation, classification, embeddings, image tasks, and speech recognition).

Since this is a single-module package, all types and APIs are available from the root module `ballerinax/huggingface`.

