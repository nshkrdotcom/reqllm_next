# Model Compat

Current-truth live compatibility and drift-detection contract for ReqLlmNext.

<!-- covers: reqllm.model_compat.real_runtime reqllm.model_compat.shared_scenarios reqllm.model_compat.layer_attribution -->

```spec-meta
id: reqllm.model_compat
kind: compat
status: active
summary: Live scenario execution, anomaly classification, and drift detection built on the same runtime architecture as normal execution.
surface:
  - guides/package_thesis.md
  - lib/mix/tasks/model_compat.ex
  - test/mix/tasks/model_compat_test.exs
  - test/coverage/anthropic_comprehensive_test.exs
  - test/coverage/openai_comprehensive_test.exs
```

## Requirements

```spec-requirements
- id: reqllm.model_compat.real_runtime
  statement: Model compatibility runs shall consume the same model normalization, planning, protocol, wire, transport, and provider architecture as normal runtime execution and shall not introduce test-only shortcuts around those layers.
  priority: must
  stability: evolving

- id: reqllm.model_compat.shared_scenarios
  statement: Model compatibility shall run shared allow-listed scenarios that exercise canonical API capabilities across providers so drift and regressions are observable on the real execution stack.
  priority: must
  stability: evolving

- id: reqllm.model_compat.layer_attribution
  statement: Compat results shall classify anomalies by architectural layer and preserve structured evidence that can be used for follow-up work and issue drafting.
  priority: must
  stability: evolving
```

## Verification

```spec-verification
- kind: source_file
  target: .spec/specs/model_compat.spec.md
  covers:
    - reqllm.model_compat.real_runtime
    - reqllm.model_compat.shared_scenarios
    - reqllm.model_compat.layer_attribution

- kind: command
  target: mix test test/mix/tasks/model_compat_test.exs
  execute: true
  covers:
    - reqllm.model_compat.real_runtime
    - reqllm.model_compat.layer_attribution
```
