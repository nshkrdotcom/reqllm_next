---
id: reqllm.decision.execution_mode_first_class
status: accepted
date: 2026-03-22
affects:
  - reqllm.architecture
  - reqllm.execution_mode
  - reqllm.execution_plan
---

# ExecutionMode Is a First-Class Runtime Object

## Context

The spike mixes two different kinds of request input:

1. hints that change endpoint selection and session behavior
2. generation parameters that only matter after the endpoint style is chosen

That makes mode-level customization hard to express. If streaming, tools, structured output, or session preference are left as scattered request options, the planner cannot cleanly support mode-level overrides for specific models.

## Decision

ReqLlmNext 2.0 normalizes mode-affecting request intent into a first-class `ExecutionMode` before policy resolution.

`ExecutionMode` carries provider-agnostic request characteristics such as:

1. operation family
2. streaming
3. tool usage
4. structured output
5. session preference
6. latency class
7. reasoning mode
8. conversation shape
9. input modalities

Generation parameters such as `temperature`, `top_p`, `max_output_tokens`, and `stop` are not part of `ExecutionMode`.

## Consequences

Mode-level overrides become easy to express without adding planner branches keyed to model names.

The planner can choose surfaces, fallbacks, and timeout behavior from a normalized request mode instead of inferring them from loosely related options.

Execution diagnostics become easier to understand because request intent and generation parameters are no longer blended together.
