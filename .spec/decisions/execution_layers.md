---
id: reqllm.decision.execution_layers
status: accepted
date: 2026-03-22
affects:
  - reqllm.architecture
  - reqllm.package
---

# Separate Semantic Protocol, Wire Format, and Transport

## Context

The current spike implementation uses `ReqLlmNext.Wire.*` modules that blend several concerns:

1. semantic API-family meaning
2. provider-facing routes and envelopes
3. transport assumptions about SSE or WebSocket delivery

That fusion made the architecture harder to reason about, especially for APIs such as OpenAI Responses where the same semantic protocol can run over HTTP/SSE or WebSocket with different client-event envelopes.

## Decision

ReqLlmNext 2.0 treats the execution stack as four separate concerns:

1. semantic protocol owns API-family meaning and canonical event decoding
2. wire format owns routes, content types, request envelopes, and inbound frame parsing
3. transport owns connection lifecycle and byte or frame movement
4. provider owns auth and endpoint roots

The planner is responsible for choosing semantic protocol, wire format, and transport for a request.

The current `Wire.*` modules remain transitional implementation code until the refactor splits them, but the architectural target and current-truth documentation now treat those concerns as distinct.

## Consequences

The long-form specs and README can describe WebSocket and SSE execution without overloading the word "wire."

Future refactors should split current `wire/` code along these boundaries instead of creating larger mixed modules.

Compatibility diagnostics and source ownership become clearer because semantic mistakes, envelope mistakes, and transport mistakes now have separate homes.
