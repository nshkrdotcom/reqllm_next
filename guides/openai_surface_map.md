# OpenAI Surface Map

Status: Working Guide

## Purpose

Map the current OpenAI public API surface against the ReqLlmNext runtime so the package can make precise support claims instead of implying blanket OpenAI coverage.

This guide focuses on two questions:

1. which OpenAI surfaces are part of ReqLlmNext's core generation story
2. which OpenAI surfaces are only partially supported or still outside the package's first-class scope

As of March 24, 2026, OpenAI's public surface is broader than ReqLlmNext's current OpenAI lane.

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
10. Utility and secondary surfaces such as background mode, batch processing, and realtime

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
9. Built-in tool helper constructors for web search, file search, code interpreter, and computer use on OpenAI Responses surfaces
10. Curated replay and live coverage for `gpt-4o-mini`, `gpt-4.1-mini`, and `o4-mini`

Current implementation homes:

1. [wire_chat.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/families/openai_compatible/wire_chat.ex)
2. [wire_embeddings.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/families/openai_compatible/wire_embeddings.ex)
3. [wire_responses.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/providers/openai/wire_responses.ex)
4. [semantic_protocol_responses.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/providers/openai/semantic_protocol_responses.ex)
5. [session_runtime_responses.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/providers/openai/session_runtime_responses.ex)
6. [transport_responses_websocket.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/providers/openai/transport_responses_websocket.ex)
7. [tools.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/providers/openai/tools.ex)
8. [openai.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/openai.ex)
9. [support_matrix.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/support_matrix.ex)
10. [openai_comprehensive_test.exs](/Users/mhostetler/Source/ReqLLM/reqllm_next/test/coverage/openai_comprehensive_test.exs)
11. [openai_websocket_coverage_test.exs](/Users/mhostetler/Source/ReqLLM/reqllm_next/test/coverage/openai_websocket_coverage_test.exs)

### Partial

These OpenAI areas exist in some form but are not yet complete first-class surfaces:

1. Built-in tools:
   request shaping and include helpers are supported, but exhaustive live lifecycle coverage is not yet in place for every tool family.
2. File inputs:
   canonical file and document inputs are supported for OpenAI-compatible chat and Responses, but ReqLlmNext does not yet expose a broader OpenAI file-upload utility surface.
3. Conversation state:
   the Responses continuation lane is implemented, but ReqLlmNext does not yet treat broader OpenAI conversation/session utilities as a separate provider utility package.
4. Utility surface differentiation:
   the package intentionally focuses on core generation and the request-side tool lane, not every OpenAI platform endpoint.

## Missing Or Out Of Scope Today

These OpenAI surfaces are not yet first-class ReqLlmNext support:

1. first-class OpenAI utility endpoints beyond core generation
2. background mode as a planned execution surface
3. batch processing utilities
4. realtime as a separate protocol family
5. vector-store and file-management utilities that would complete file-search workflows
6. exhaustive live coverage for every built-in tool lifecycle and result shape

## Recommended Package Boundary

ReqLlmNext should keep the OpenAI story intentionally split:

1. core generation surfaces remain first-class
2. OpenAI-compatible defaults remain reusable for providers that fit the same happy path
3. provider-native built-in tool request helpers stay scoped to OpenAI Responses
4. utility endpoints beyond core generation should be introduced only as explicit provider-owned surfaces, not as silent planner creep
5. realtime should be treated as a distinct protocol family rather than an extension of the current Responses lane

## Package Impact

The honest OpenAI support claim today is:

ReqLlmNext has deep core coverage for OpenAI-compatible chat, Responses HTTP, Responses WebSocket mode, embeddings, prompt caching, file inputs, and continuation. It does not yet claim the full OpenAI platform surface beyond those lanes.
