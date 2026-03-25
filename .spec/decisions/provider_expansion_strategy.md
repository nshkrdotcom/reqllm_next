---
id: reqllm.decision.provider_expansion_strategy
status: accepted
date: 2026-03-25
affects:
  - reqllm.architecture
  - reqllm.model_compat
  - reqllm.model_input
  - reqllm.telemetry
  - reqllm.workflow
  - reqllm.diagnostics
---

# Provider Expansion Strategy

## Context

ReqLlmNext now has a stable execution-plan architecture, a compile-time extension system, a replay-first verification model, a sparse live-verifier lane, and a first proof that OpenAI-compatible family reuse works through DeepSeek.

The next pressure comes from provider expansion.

The old `ReqLLM` package supported many more providers, but they did not all carry the same architectural weight:

1. some were mostly OpenAI-compatible with a few provider-specific options
2. some were cloud wrappers over multiple provider families
3. some introduced genuinely new semantics or new operation families
4. some were aliases or endpoint variants that do not justify separate first-class provider surfaces in ReqLlmNext

Without an explicit policy, expansion work risks drifting back toward the spike-era pattern of porting providers opportunistically and rebuilding provider sprawl inside shared layers.

## Decision

ReqLlmNext will expand providers in this order:

1. OpenAI-compatible providers that can ride an existing family with narrow provider-owned deltas
2. providers that still fit existing operations but need sharper provider-specific shaping
3. genuinely new provider families and operation families
4. cloud wrapper platforms with multi-family routing semantics

Current near-term priority providers from old `ReqLLM` support are:

1. Groq
2. OpenRouter
3. vLLM
4. xAI
5. Venice
6. Alibaba
7. Cerebras
8. ZAI
9. Zenmux
10. Google Gemini
11. ElevenLabs
12. Cohere

Azure, Google Vertex, and Amazon Bedrock are intentionally deferred because they are wrapper platforms, not simple provider additions.

Provider additions shall follow these rules:

1. prefer family reuse before adding new shared abstractions
2. keep provider behavior in provider and family slices, not in shared planner branching
3. add replay-first proof by default
4. add sparse live verifier coverage only for representative high-signal lanes
5. avoid porting alias-style providers when a cleaner family or variant model is enough

The current working assumptions for the deferred wrappers are:

1. Azure and Google Vertex should eventually be treated as cloud routing platforms over multiple family adapters
2. Amazon Bedrock should eventually be treated as a native cloud family platform with provider-specific auth and model-family formatting
3. none of those should drive the next round of provider expansion decisions

## Consequences

Benefits:

1. expansion work stays aligned with the existing extension architecture
2. the next providers exercise the OpenAI-compatible reuse path instead of bypassing it
3. proof depth stays realistic and cost-aware
4. wrapper platforms do not distort the near-term provider roadmap

Tradeoffs:

1. some highly requested providers are intentionally deferred
2. provider count will grow more slowly than old `ReqLLM`
3. some old alias-style endpoints may not return as separate top-level providers

## Notes

This decision is about sequencing and architectural posture.

It does not require every future provider to use the OpenAI-compatible family.
It does require new providers to justify why they cannot reuse an existing family before they introduce new shared behavior.
