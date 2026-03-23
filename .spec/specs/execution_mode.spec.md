# Execution Mode

Current-truth normalized request-mode contract for ReqLlmNext 2.0.

```spec-meta
id: reqllm.execution_mode
kind: execution_mode
status: active
summary: Canonical provider-agnostic request mode normalized before policy resolution.
surface:
  - specs/execution_mode.md
  - specs/operation_planner.md
  - specs/architecture.md
decisions:
  - reqllm.decision.execution_mode_first_class
```

## Requirements

```spec-requirements
- id: reqllm.execution_mode.normalized_shape
  statement: ReqLlmNext shall normalize mode-affecting request intent into a provider-agnostic `ExecutionMode` that captures operation, streaming, tools, structured output, session preference, latency class, reasoning, conversation shape, and input modalities.
  priority: must
  stability: evolving

- id: reqllm.execution_mode.mode_hints_before_policy
  statement: ReqLlmNext shall resolve mode hints into `ExecutionMode` before policy rules choose surfaces, defaults, timeouts, or fallbacks.
  priority: must
  stability: evolving
```

## Verification

```spec-verification
- kind: source_file
  target: specs/execution_mode.md
  covers:
    - reqllm.execution_mode.normalized_shape
    - reqllm.execution_mode.mode_hints_before_policy
```
