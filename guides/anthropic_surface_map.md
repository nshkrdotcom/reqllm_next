# Anthropic Surface Map

Status: Working Guide

## Purpose

Map the current Anthropic API surface against the ReqLlmNext v2 runtime so new Anthropic work lands on the right architectural boundary.

This guide is intentionally practical. It is not trying to restate all Anthropic docs. It is trying to answer:

1. what Anthropic officially exposes today
2. what ReqLlmNext already supports
3. what is partial
4. what is still missing
5. which runtime layer should own each gap

As of March 24, 2026, the official Anthropic surface is broader than the current ReqLlmNext Anthropic lane.

## Official Surface

The official Anthropic developer docs currently cover at least these API and feature areas:

1. Messages API
2. Token counting
3. Message batches
4. Files API
5. Prompt caching
6. Large context windows, including 1M-context beta lanes on supported models
7. PDF and document support
8. Native structured outputs
9. Citations and search-result style output blocks
10. Server-hosted tools such as web search and code execution
11. MCP connector support in the Messages API
12. Computer use
13. OpenAI SDK compatibility

Official sources used for this map:

1. [Messages API](https://docs.anthropic.com/en/api/messages)
2. [Message Batches](https://docs.anthropic.com/en/docs/build-with-claude/batch-processing)
3. [Token counting](https://docs.anthropic.com/en/api/counting-tokens)
4. [Files upload](https://docs.anthropic.com/en/api/files-upload)
5. [Prompt caching](https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching)
6. [Context windows](https://docs.anthropic.com/en/docs/build-with-claude/context-windows)
7. [Tool use overview](https://docs.anthropic.com/en/docs/agents-and-tools/tool-use/overview)
8. [Web search tool](https://docs.anthropic.com/en/docs/agents-and-tools/tool-use/web-search-tool)
9. [Code execution tool](https://docs.anthropic.com/en/docs/agents-and-tools/tool-use/code-execution-tool)
10. [Computer use](https://docs.anthropic.com/en/docs/agents-and-tools/tool-use/computer-use)
11. [MCP connector](https://docs.anthropic.com/en/docs/agents-and-tools/mcp-connector)
12. [Citations](https://platform.claude.com/docs/en/build-with-claude/citations)
13. [OpenAI SDK compatibility](https://platform.claude.com/docs/en/api/openai-sdk)
14. [Release notes overview](https://platform.claude.com/docs/en/release-notes/overview)

## Current ReqLlmNext Coverage

### Supported

ReqLlmNext currently supports a real Anthropic Messages lane through the v2 planning stack:

1. text generation over the Anthropic Messages API
2. streaming SSE decoding
3. tool-use round trips with client tools
4. image input
5. Anthropic-native structured outputs through `output_config.format`
6. reasoning or thinking mode
7. prompt caching headers and normalized usage handling
8. 1M-context beta-header injection
9. document blocks, `file_id` document references, and container-upload content blocks
10. token counting utility support
11. files utility support for upload, get, list, delete, and binary download
12. message batches utility support for create, get, list, cancel, delete, and JSONL results retrieval
13. provider-native tool helpers for web search, code execution, MCP connectors, and computer use
14. curated live and replay verification for Haiku 4.5, Sonnet 4.6, and Opus 4.6
15. version-aware beta-header handling for newer MCP, computer-use, and dynamic web-tool lanes

Current implementation homes:

1. [anthropic.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/providers/anthropic/wire_messages.ex)
2. [anthropic_messages.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/providers/anthropic/semantic_protocol_messages.ex)
3. [anthropic.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/anthropic.ex)
4. [client.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/providers/anthropic/client.ex)
5. [files.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/providers/anthropic/files.ex)
6. [token_count.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/providers/anthropic/token_count.ex)
7. [message_batches.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/providers/anthropic/message_batches.ex)
8. [tools.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/providers/anthropic/tools.ex)
9. [support_matrix.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/support_matrix.ex)
10. [anthropic_comprehensive_test.exs](/Users/mhostetler/Source/ReqLLM/reqllm_next/test/coverage/anthropic_comprehensive_test.exs)
11. [anthropic_beta_features_test.exs](/Users/mhostetler/Source/ReqLLM/reqllm_next/test/provider_features/anthropic_beta_features_test.exs)
12. [anthropic_advanced_messages_test.exs](/Users/mhostetler/Source/ReqLLM/reqllm_next/test/provider_features/anthropic_advanced_messages_test.exs)

### Partial

These areas exist in some form but are not yet first-class Anthropic surfaces:

1. Citations and search-result normalization:
   request-side citation enablement and search-result content parts are supported, but the canonical response model still treats many richer citation shapes as provider metadata rather than a fully generalized cross-provider content system.
2. Context editing and compaction:
   ReqLlmNext now forwards `context_management` controls and preserves richer stop metadata, but there is not yet a full session-runtime story around automatic compaction loops or pause-turn continuation.
3. Provider-native tools:
   web search and code execution now have live provider-feature coverage for the native Messages lane, but MCP, computer use, and the full range of server-tool result shapes are not yet exhaustively pressure-tested.
4. Versioned tool defaults:
   ReqLlmNext now distinguishes between broadly compatible defaults and newer doc versions for Anthropic server tools. Newer tool variants can opt in through helper options and trigger the matching beta headers, but the package does not yet have exhaustive live verification for every versioned tool combination across Claude model families.
5. Context management:
   request shaping is implemented and covered at the wire layer, but ReqLlmNext is not yet claiming a stable live context-management lane in the broader provider coverage suite.

## Missing Surface Areas

These Anthropic areas are not yet first-class ReqLlmNext support:

1. exhaustive live coverage for every provider-native tool lifecycle
2. persistent pause-turn and compaction session handling
3. richer refusal and citation normalization into the canonical response model
4. OpenAI-compat Anthropic lane as a deliberate secondary evaluation surface

## Ownership Map

The wide Anthropic surface should not be implemented as one giant provider blob.

The intended ownership split is:

1. Planning and profile
   - decide whether a capability is a new execution surface
   - expose supported parameter shapes and fallback rules
2. Semantic protocol
   - normalize Anthropic-specific event and content-block semantics
   - own citations, pause-turn-like stops, refusal metadata, and server-tool result shapes
3. Wire
   - encode Anthropic request envelopes
   - encode beta headers, tool specs, file references, and Anthropic-native structured-output payloads
4. Transport
   - likely remains HTTP or SSE for most Anthropic work
   - should only change if Anthropic introduces a distinct transport requirement
5. Fixtures and compat
   - prove each added surface through replay-first tests and carefully chosen live recordings
6. Diagnostics
   - make it obvious whether a failure belongs to planning, protocol normalization, wire encoding, provider behavior, or feature gating

## Recommended Order

The current recommended order for wide Anthropic work is:

1. complete the Anthropic Messages lane first
2. add provider-specific utility surfaces for non-message endpoints
3. pressure-test representative live lanes before broadening model count
4. evaluate the OpenAI compatibility layer separately from the native Anthropic lane

That order keeps the main Messages lane improving first, while confining provider-specific extras to explicit homes instead of leaking them into the canonical package surface.
