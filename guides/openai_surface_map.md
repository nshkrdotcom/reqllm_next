# OpenAI Surface Map

Status: Working Guide

## Purpose

Map the current OpenAI public API surface against the ReqLlmNext runtime so the package can make precise support claims instead of implying blanket OpenAI coverage.

This guide focuses on two questions:

1. which OpenAI surfaces are part of ReqLlmNext's core generation story
2. which OpenAI surfaces are only partially supported or still outside the package's first-class scope

As of March 25, 2026, OpenAI's public surface is broader than ReqLlmNext's current OpenAI lane.

## Official Surface

The current OpenAI docs cover at least these API and feature areas that matter to ReqLlmNext's architecture:

1. Responses API
2. OpenAI-compatible chat generation
3. Embeddings
4. WebSocket mode for Responses
5. Conversation state with `previous_response_id`
6. Structured outputs
7. File inputs and document inputs
8. Prompt caching
9. Built-in tools such as web search, file search, code interpreter, and computer use
10. Image edits
11. Audio translations and richer speech-to-text variants such as diarization
12. Utility and secondary surfaces such as background mode, batch processing, and realtime
13. Files, uploads, vector stores, and related file-search workflow utilities
14. Run-and-scale utilities such as webhooks, token counting, compaction, and optimization controls
15. Advanced agentic tool surfaces such as MCP/connectors, Skills, hosted shell, apply patch, and tool search
16. Additional provider-owned surfaces such as video generation and moderation

Official sources used for this map:

1. [Models](https://developers.openai.com/api/docs/models)
2. [File inputs](https://developers.openai.com/api/docs/guides/file-inputs)
3. [Prompt caching](https://developers.openai.com/api/docs/guides/prompt-caching)
4. [WebSocket mode](https://developers.openai.com/api/docs/guides/websocket-mode)
5. [Conversation state](https://developers.openai.com/api/docs/guides/conversation-state)
6. [Structured outputs](https://developers.openai.com/api/docs/guides/structured-outputs)

## Current ReqLlmNext Coverage

### Supported

ReqLlmNext currently has a strong OpenAI core generation lane through the v2 execution stack:

1. OpenAI-compatible chat generation for text, tools, images, and object generation
2. OpenAI Responses generation over HTTP
3. OpenAI Responses generation over WebSocket mode
4. Embeddings
5. Responses continuation through `previous_response_id`
6. Native structured outputs where the selected surface supports them
7. Prompt caching request controls and normalized cache-aware usage metadata
8. File and document request shaping for attachment-capable models
9. Built-in tool helper constructors for web search, file search, code interpreter, computer use, MCP, hosted shell, apply patch, local shell, tool search, Skills, and image generation on OpenAI Responses surfaces
10. Standalone image generation and image edits
11. Standalone transcription, translation, and speech generation
12. Richer transcription normalization with segment and speaker-count provider metadata
13. Provider-owned OpenAI utility surfaces for files, vector stores, responses retrieval and compaction, input-token counting, background responses, conversations, batches, moderation, videos, webhooks, and realtime
14. Curated replay and live coverage for `gpt-4o-mini`, `gpt-4.1-mini`, and `o4-mini`

Current implementation homes:

1. [wire_chat.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/families/openai_compatible/wire_chat.ex)
2. [wire_embeddings.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/families/openai_compatible/wire_embeddings.ex)
3. [wire_responses.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/providers/openai/wire_responses.ex)
4. [semantic_protocol_responses.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/providers/openai/semantic_protocol_responses.ex)
5. [session_runtime_responses.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/providers/openai/session_runtime_responses.ex)
6. [transport_responses_websocket.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/providers/openai/transport_responses_websocket.ex)
7. [tools.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/providers/openai/tools.ex)
8. [responses.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/providers/openai/responses.ex)
9. [files.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/providers/openai/files.ex)
10. [vector_stores.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/providers/openai/vector_stores.ex)
11. [background.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/providers/openai/background.ex)
12. [batches.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/providers/openai/batches.ex)
13. [conversations.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/providers/openai/conversations.ex)
14. [videos.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/providers/openai/videos.ex)
15. [webhooks.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/providers/openai/webhooks.ex)
16. [realtime.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/providers/openai/realtime.ex)
17. [openai.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/openai.ex)
18. [support_matrix.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/support_matrix.ex)
19. [openai_comprehensive_test.exs](/Users/mhostetler/Source/ReqLLM/reqllm_next/test/coverage/openai_comprehensive_test.exs)
20. [openai_websocket_coverage_test.exs](/Users/mhostetler/Source/ReqLLM/reqllm_next/test/coverage/openai_websocket_coverage_test.exs)

### Partial

These OpenAI areas exist in some form but are not yet complete first-class surfaces:

1. Built-in tools:
   request shaping, include helpers, and terminal lifecycle normalization are supported, but exhaustive live coverage is still not in place for every tool family and result shape.
2. Realtime:
   ReqLlmNext now has a first-class transport-agnostic realtime core with an OpenAI adapter. The package owns canonical realtime commands, events, and session reduction, while socket hosting may still live above the package boundary.
3. Webhooks:
   webhook event parsing and categorization are supported, but this package does not yet claim full webhook signature-verification or dashboard-management coverage.
4. Utility and secondary surfaces:
   the package now covers a wide OpenAI provider-owned utility surface, but curated replay/live verification still focuses on the core generation lanes rather than every utility endpoint.

## Missing Or Out Of Scope Today

These OpenAI surfaces are not yet first-class ReqLlmNext support:

1. exhaustive live verification for every built-in OpenAI tool family and result shape
2. full webhook signature and delivery-management coverage
3. exhaustive live verification for every realtime event family and session workflow
4. broad utility-surface live fixtures on the same level as the core support matrix

## Recommended Package Boundary

ReqLlmNext should keep the OpenAI story intentionally split:

1. core generation surfaces remain first-class
2. OpenAI-compatible defaults remain reusable for providers that fit the same happy path
3. provider-native built-in tool request helpers stay scoped to OpenAI Responses
4. image edits and audio translations extend the existing media lane through the same top-level media facade instead of inventing a parallel OpenAI-only public API
5. utility endpoints beyond core generation are explicit provider-owned surfaces, not silent planner creep
6. realtime is treated as a first-class package concept with an OpenAI adapter rather than as a quiet extension of the current Responses lane
7. Anthropic's standalone media boundary remains explicit rather than forcing fake symmetry with OpenAI

## Package Impact

The honest OpenAI support claim today is:

ReqLlmNext has deep core coverage for OpenAI-compatible chat, Responses HTTP, Responses WebSocket mode, embeddings, prompt caching, file inputs, continuation, built-in tool helpers, standalone media operations including image edits and translations, and a first-class realtime core with an OpenAI adapter. It also now exposes a broad provider-owned OpenAI utility surface for files, vector stores, responses, conversations, background mode, batches, moderation, videos, and webhooks. The remaining honest gaps are mostly around exhaustive live verification and a few deliberately provider-owned surfaces that do not expand the top-level cross-provider facade.
