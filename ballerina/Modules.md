## Modules

### `huggingface`

The default module of this package, which provides:

- The `Client` for communicating with the Hugging Face Inference API.
- Configuration records `ConnectionConfig`, `RetryConfig`, and `RagConfig`.
- The `Conversation` class for stateful chat history management.
- The `inferModel` and `batchInfer` generic helpers for calling any Hugging Face model.
- Model metadata helpers `getModelInfo` and `checkModelAvailability`.
- The `ragQuery` RAG pipeline helper for retrieval-augmented generation.
- Strongly-typed request and response records for all supported operations (chat completions, streaming, text generation, classification, NER, embeddings, question answering, summarization, translation, zero-shot classification, image generation, image classification, and speech recognition) including batch endpoints.

Since this is a single-module package, all types and APIs are available from the root module `avi0ra/huggingface`.
