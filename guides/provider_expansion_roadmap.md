# Provider Expansion Roadmap

Status: Working Guide

<!-- covers: reqllm.model_compat.provider_expansion_ordering -->

## Purpose

Record the practical provider-addition order for ReqLlmNext now that the package has:

1. deterministic planning
2. provider and family slice homes
3. compile-time extension manifests
4. replay-first verification
5. sparse live verifier tests

This guide is intentionally narrower than the package thesis. It exists to keep provider work aligned with the current architecture instead of re-importing the looser patterns from old `ReqLLM`.

The roadmap now assumes three runtime support tiers:

1. first-class providers with dedicated provider slices
2. best-effort packaged providers executed through typed `LLMDB` runtime metadata and an existing canonical family
3. unsupported or catalog-only models that should fail fast with an explicit reason

## Expansion Rules

Add providers in this order:

1. providers that ride existing families cleanly
2. providers that need moderate provider-owned deltas
3. providers that require a new family or operation family
4. cloud wrapper platforms last

That ordering matters because ReqLlmNext is trying to prove that provider growth can stay local to:

1. LLMDB metadata
2. provider facts
3. declared family and provider seams
4. provider-owned protocol, wire, transport, and utility modules

If a provider addition starts by touching shared planner logic, that should be treated as a warning sign.

## Completed Expansion Wave

### First Wave: OpenAI-Compatible Reuse

These now ride the existing OpenAI-compatible family with provider-owned deltas:

1. Groq
2. OpenRouter
3. vLLM
4. xAI
5. Venice
6. Alibaba

### Second Wave: Sharper OpenAI-Compatible Deltas

These now fit the current execution model with sharper provider-specific shaping:

1. Cerebras
2. ZAI
3. Zenmux

### Third Wave: New Families

These now provide the first native non-OpenAI-family pressure on the package:

1. Google Gemini
2. ElevenLabs
3. Cohere

## Current Deferred Queue

### Wrapper Platforms

These are explicitly deferred for now:

1. Azure
2. Google Vertex
3. Amazon Bedrock

They should be treated as cloud wrapper platforms, not as simple provider ports.

## What This Proved

The completed provider wave showed that:

1. OpenAI-compatible growth can stay local to provider slices and manifest declarations
2. new native families can land without reopening shared planner branching
3. replay-backed provider-slice tests plus a curated best-effort provider matrix are a sustainable default proof system for expansion work
4. sparse live verifier coverage should remain curated around Anthropic and OpenAI anchor lanes instead of becoming a broad provider matrix

It also means new provider work should ask one question up front:

1. should this provider become first-class now, or is best-effort execution through typed `LLMDB` runtime metadata enough for the current promise

## Next Pressure

The next useful work after this wave is:

1. deeper fixture and live-verifier proof for representative non-OpenAI providers when keys are available
2. selective provider-native utility expansion where the public facade should stay unchanged
3. eventual wrapper-platform design work for Azure, Google Vertex, and Amazon Bedrock

## Verification Expectations

Every provider addition should land with:

1. replay-backed public or provider-slice tests
2. provider-specific unit and wire tests where request shaping matters
3. fixture evidence for representative lanes when live keys are available
4. guide and spec reconciliation

Providers that stay best-effort should still be exercised by the curated metadata-driven proof matrix so the generic runtime path does not silently drift.

Only representative lanes should become live verifier tests.

The package should not build a broad live-provider matrix into routine verification.

## Non-Goals

This roadmap does not imply that:

1. every provider from old `ReqLLM` must return unchanged
2. alias-style endpoints need separate top-level providers in ReqLlmNext
3. wrappers should be ported before family reuse is well-proven

The point is architectural pressure with controlled scope, not raw provider count.
