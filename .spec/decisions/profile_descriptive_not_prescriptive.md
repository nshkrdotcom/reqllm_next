---
id: reqllm.decision.profile_descriptive_not_prescriptive
status: accepted
date: 2026-03-22
affects:
  - reqllm.architecture
  - reqllm.model_profile
  - reqllm.execution_plan
---

# ModelProfile Is Descriptive, Not Prescriptive

## Context

The spike implementation and early notes mixed several kinds of information together:

1. durable model facts from `LLMDB`
2. stable defaults and constraints metadata
3. request-time decisions about transports, sessions, and fallbacks

That works poorly once the same model may run in multiple modes or across multiple endpoint styles. A profile that tries to carry both facts and request policy quickly becomes unstable and encourages downstream layers to treat metadata as already-planned behavior.

## Decision

ReqLlmNext 2.0 treats `ModelProfile` as a descriptive object only.

`ModelProfile` may contain request-independent facts such as:

1. supported operations and features
2. modalities and limits
3. stable parameter defaults and constraints metadata
4. session capabilities
5. declared `ExecutionSurface` entries

`ModelProfile` must not choose:

1. the primary surface for a request
2. fallback surfaces
3. session strategy
4. timeout policy
5. mode-specific behavior

Those choices belong to `ExecutionMode`, policy rules, and `ExecutionPlan`.

## Consequences

Model facts remain serializable, reusable, and easier to validate independently of request intent.

Mode-specific model behavior moves out of metadata interpretation code and into explicit policy resolution.

Downstream execution layers can rely on `ExecutionPlan` for prescriptive behavior instead of trying to infer request strategy from `ModelProfile`.
