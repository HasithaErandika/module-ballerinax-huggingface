## Modules

### `huggingface`

The default module of this package, which provides:

- The `Client` for communicating with the Hugging Face Inference API.
- Configuration records `ConnectionConfig` and `RetryConfig`.
- The `inferModel` generic helper for calling any Hugging Face model.
- The `ragQuery` RAG pipeline helper for retrieval-augmented generation.
- Strongly-typed request and response records for all supported operations (chat completions, streaming, text generation, classification, NER, embeddings, question answering, summarization, translation, zero-shot classification, image generation, image classification, and speech recognition).

Since this is a single-module package, all types and APIs are available from the root module `avi0ra/huggingface`.
