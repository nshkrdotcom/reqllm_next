---
id: reqllm.decision.runtime_telemetry_kernel
status: accepted
date: 2026-03-25
affects:
  - reqllm.architecture
  - reqllm.telemetry
  - reqllm.package
---

# Use One Telemetry Kernel for Runtime Events

## Context

ReqLlmNext needs durable diagnostics across planning, execution, fixtures, streaming, provider requests, utility endpoints, and compatibility tooling. Direct ad hoc `:telemetry` emission from many layers would make event names, metadata shape, and redaction drift over time.

## Decision

ReqLlmNext now centralizes runtime event emission in `ReqLlmNext.Telemetry`.

The telemetry kernel owns:

1. stable event families and measurement naming
2. metadata redaction and sanitization
3. request and provider-request spans
4. stream lifecycle instrumentation
5. canonical metadata extraction from plans, models, execution stacks, and normalized usage

Runtime layers should emit through `ReqLlmNext.Telemetry` instead of calling `:telemetry` directly for package-level events.

## Consequences

Applications and compat tooling can subscribe to one stable package telemetry contract.

Sensitive payloads and reasoning text remain subject to one redaction policy instead of many informal call sites.

New runtime layers such as realtime and provider-owned utilities can adopt the same event taxonomy without inventing parallel naming schemes.
