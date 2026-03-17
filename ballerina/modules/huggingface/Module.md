Provides the `avi0ra/huggingface` connector for the [Hugging Face Inference API](https://huggingface.co/docs/api-inference/index).

This module contains:

- `Client` – typed HTTP client for 12+ AI/ML tasks (chat completion, text generation, classification, embeddings, summarization, translation, image generation, speech recognition, and more).
- `inferModel` – generic helper for calling any model not covered by the typed operations.
- `ragQuery` – built-in RAG pipeline with embedding, similarity ranking, and grounded generation.
- `RetryConfig` – automatic retry with exponential backoff for cold-starting models (HTTP 503).
- `ConnectionConfig` – configuration for client authentication and HTTP behaviour.
- Strongly-typed request/response records for all supported operations.

Use this module by importing `avi0ra/huggingface` in your Ballerina program. See `Package.md` for full API documentation and examples.
