# Enforcement Spec

Status: Proposed

## Objective

Define how ReqLlmNext enforces the architecture boundary in code so model metadata remains declarative and execution logic does not drift into raw metadata access and ad hoc capability checks.

## Core Rule

Raw model metadata is accepted at the edge, normalized once, and must hard-fail if invalid.

After normalization and request-mode derivation:

1. execution code works with `%ModelProfile{}`
2. request intent works with `%ExecutionMode{}`
3. request execution works with `%ExecutionPlan{}`
4. raw `%LLMDB.Model{}` values are forbidden

## Runtime-First Enforcement

ReqLlmNext should use runtime hard-fail validation, not macro-heavy compile-time machinery.

Reasons:

1. `%LLMDB.Model{}` is runtime data
2. provider/model metadata changes over time
3. compile-time validation cannot protect the full input surface

Compile-time checks may exist for repo-local fixtures, but they are optional. Runtime validation is the real boundary.

## Zoi Usage

`zoi` is the recommended enforcement mechanism for the model boundary.

Use it for:

1. canonical `%ModelProfile{}` validation
2. override/config validation
3. strict unknown-key rejection
4. enum and nested-shape validation

Do not use it for:

1. planning policy
2. protocol selection logic
3. transport behavior
4. provider behavior

`zoi` validates facts. It does not decide execution behavior.

## Hard-Fail Rules

Normalization must fail on:

1. unknown top-level keys
2. unknown nested keys
3. unknown operation names
4. unknown feature names
5. unknown transport or protocol names
6. invalid enum values
7. missing required fields
8. invalid source combinations
9. unsupported profile combinations
10. any attempt to create new atoms from user-provided keys or values

There is no best-effort fallback after normalization.

## Allowed Boundary Modules

Only the model boundary may interpret:

1. string model specs
2. `%LLMDB.Model{}`
3. source-specific raw metadata keys

Only the following concerns may interpret canonical profile facts:

1. `ModelProfile`
2. `OperationPlanner`
3. `ExecutionMode`
4. validation logic owned by planning

Transport, provider, protocol, and session modules must consume resolved values, not raw facts.

## CI Guardrails

Docs are not sufficient. CI should fail on boundary violations.

Required guardrails:

1. lint rule forbidding direct `model.capabilities` access outside the allowed boundary
2. lint rule forbidding `get_in(model, [:capabilities, ...])` outside the allowed boundary
3. lint rule forbidding `%LLMDB.Model{}` in execution modules after profile normalization
4. boundary tests asserting public runtime APIs reject tuple, map, or other non-supported model input types
5. boundary tests asserting transport modules do not inspect model facts
6. boundary tests asserting semantic protocol modules do not infer capability support
7. lint or boundary rules forbidding compat or issue-filing logic from mutating runtime layers
8. lint or boundary rules forbidding scattered model-name branching in runtime execution code

## Error Model

Boundary failures must be explicit and structured.

Examples:

1. `{:error, %ReqLlmNext.Error.InvalidModelSpec{...}}`
2. `{:error, %ReqLlmNext.Error.InvalidModelProfile{...}}`
3. `{:error, %ReqLlmNext.Error.UnsupportedOperation{...}}`

Internal bang variants are allowed inside the boundary as long as public APIs return tagged tuples consistently.
