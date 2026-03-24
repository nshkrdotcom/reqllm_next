# Execution Mode

Current-truth normalized request-mode contract for ReqLlmNext 2.0.

<!-- covers: reqllm.execution_mode.normalized_shape reqllm.execution_mode.mode_hints_before_policy reqllm.execution_mode.provider_agnostic -->

```spec-meta
id: reqllm.execution_mode
kind: execution_mode
status: active
summary: Canonical provider-agnostic request mode normalized before policy resolution.
surface:
  - lib/req_llm_next/execution_mode.ex
  - lib/req_llm_next/operation_planner.ex
decisions:
  - reqllm.decision.execution_mode_first_class
```

## Requirements

```spec-requirements
- id: reqllm.execution_mode.normalized_shape
  statement: ReqLlmNext shall normalize mode-affecting request intent into a provider-agnostic `ExecutionMode` that captures operation, streaming, tools, structured output, session preference, latency class, reasoning, conversation shape, and input modalities, including richer modalities such as document input when present in canonical context parts.
  priority: must
  stability: evolving

- id: reqllm.execution_mode.mode_hints_before_policy
  statement: ReqLlmNext shall resolve mode hints into `ExecutionMode` before policy rules choose surfaces, defaults, timeouts, or fallbacks, including preserving explicit transport, session, reasoning, and structured-output intent so policy can apply compatibility checks consistently across text, object, and embedding requests.
  priority: must
  stability: evolving

- id: reqllm.execution_mode.provider_agnostic
  statement: `ExecutionMode` shall remain provider-agnostic and shall not contain chosen surfaces, chosen protocols, encoded payloads, raw tool definitions, or provider-native helper maps, even though extension criteria and policy may later match on its normalized flags.
  priority: must
  stability: evolving
```

## Verification

```spec-verification
- kind: source_file
  target: .spec/specs/execution_mode.spec.md
  covers:
    - reqllm.execution_mode.normalized_shape
    - reqllm.execution_mode.mode_hints_before_policy
    - reqllm.execution_mode.provider_agnostic

- kind: command
  target: mix test test/operation_planner_test.exs
  execute: true
  covers:
    - reqllm.execution_mode.normalized_shape
    - reqllm.execution_mode.mode_hints_before_policy
```
