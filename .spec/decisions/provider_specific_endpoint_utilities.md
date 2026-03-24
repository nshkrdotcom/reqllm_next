---
id: reqllm.decision.provider_specific_endpoint_utilities
status: accepted
date: 2026-03-23
affects:
  - reqllm.package
  - reqllm.provider
  - reqllm.source_layout
  - reqllm.model_compat
---

# Provider-Specific Endpoint Utilities

## Context

ReqLlmNext has a narrow canonical public API centered on `generate_text`, `stream_text`, `generate_object`, and `embed`.

Some providers expose additional endpoints that matter for real support work but do not belong on that top-level cross-provider facade. Anthropic is the current example:

1. token counting
2. files upload and metadata
3. message batches
4. provider-native tool and MCP connector helper shapes

Those features are important for provider coverage, but forcing them through the top-level facade would collapse concerns and weaken the package’s core contract.

## Decision

ReqLlmNext will keep the cross-provider public API narrow and add explicit provider-scoped utility modules for non-canonical provider endpoints.

For Anthropic, those homes are:

1. `ReqLlmNext.Anthropic`
2. `ReqLlmNext.Anthropic.Client`
3. `ReqLlmNext.Anthropic.Files`
4. `ReqLlmNext.Anthropic.TokenCount`
5. `ReqLlmNext.Anthropic.MessageBatches`
6. `ReqLlmNext.Anthropic.Tools`

## Consequences

Positive:

1. the main `ReqLlmNext` API stays stable and easy to understand
2. provider-native endpoints get first-class support without distorting the canonical facade
3. non-message provider features can still be tested, documented, and evolved under Spec Led discipline

Tradeoffs:

1. some provider features live outside the main public facade
2. provider-specific utility modules must be documented clearly so they do not feel ad hoc

## Related

1. [execution_layers.md](/Users/mhostetler/Source/ReqLLM/reqllm_next/.spec/decisions/execution_layers.md)
2. [package_thesis.md](/Users/mhostetler/Source/ReqLLM/reqllm_next/guides/package_thesis.md)
