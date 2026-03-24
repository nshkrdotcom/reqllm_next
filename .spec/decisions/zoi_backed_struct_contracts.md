---
id: reqllm.decision.zoi_backed_struct_contracts
status: accepted
date: 2026-03-24
affects:
  - reqllm.package
  - reqllm.source_layout
  - reqllm.workflow
---

# Zoi-Backed Struct Contracts

## Context

ReqLlmNext has converged on a set of package-owned structs that carry canonical request, response, planning, runtime-state, and extension-manifest data through the system.

Using Zoi for some of those structs and plain `defstruct` for others weakens required-key enforcement, defaults, schema introspection, and contributor expectations.

## Decision

ReqLlmNext standardizes package-owned structs on Zoi-backed schemas.

When a module in `lib/req_llm_next/` defines a package-owned struct, it should:

1. declare the struct shape through `Zoi.struct`
2. enforce required keys through `Zoi.Struct.enforce_keys`
3. derive struct fields from the Zoi schema
4. expose `schema/0`
5. expose constructor helpers such as `new/1` and `new!/1` when they add practical value

This applies to canonical public-facing structs and internal runtime-contract structs alike when they represent stable package data rather than one-off local implementation details.

## Consequences

Positive:
1. package contract shapes become more explicit and introspectable
2. defaults and required fields stay consistent across public and internal data contracts
3. contributors get one clear pattern for adding or evolving structs
4. tests can assert schema presence directly for core package contracts

Tradeoffs:
1. small internal structs carry a bit more declaration ceremony
2. some modules will still use `Zoi.any()` for values that are difficult to express more narrowly
3. contributors need to learn one more package-level convention

Guardrails:
1. this does not mean every runtime module should become a struct
2. plain data maps may still be appropriate for transient provider payloads or raw decoded events
3. the goal is consistent struct contracts, not gratuitous schema layers around every local variable
