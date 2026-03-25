---
id: reqllm.decision.transport_agnostic_realtime_core
status: accepted
date: 2026-03-25
affects:
  - reqllm.architecture
  - reqllm.layer_boundaries
  - reqllm.package
---

# Make Realtime First-Class but Transport-Agnostic

## Context

OpenAI Realtime began as a provider-owned utility surface. That kept the lower layers clean, but it did not embody the package thesis that canonical meaning should be owned inside ReqLlmNext while concrete byte movement and connection hosting remain separate concerns.

At the same time, ReqLlmNext should not become a WebSocket host. Applications or higher-level transports may want to own socket lifecycle above the package.

## Decision

ReqLlmNext now treats realtime as a first-class package concept through a shared `ReqLlmNext.Realtime` core with canonical commands, canonical events, and session-state reduction.

The package owns:

1. canonical realtime commands and events
2. provider-specific adapter modules that encode commands and decode provider events
3. canonical session-state reduction and output-item materialization
4. optional provider-owned streaming helpers built on top of that shared core

The package does not require ownership of the host WebSocket lifecycle. A higher layer may carry encoded provider events over WebSockets or another transport while ReqLlmNext continues to own canonical meaning and state reduction.

## Consequences

Realtime is no longer merely an OpenAI utility helper. It is a package-level architectural concept with provider adapters.

OpenAI remains the first concrete realtime adapter, but the shared core is now available for future providers without forcing WebSocket hosting into the facade or planner.
