# Source Layout Spec

Status: Proposed

## Objective

Define where model quirks, policy logic, and execution-layer anomalies belong in the source tree so the system can scale without architectural drift.

## Purpose

ReqLlmNext is expected to support many providers, endpoint styles, and model-specific quirks.

That stays maintainable only if every concern has an obvious home in the codebase.

## Ownership Rules

1. model-boundary concerns belong in model resolution modules
   - public `ModelRef` normalization
   - `%LLMDB.Model{}` handling
   - profile construction

2. descriptive model facts belong in model profile modules
   - operations
   - features
   - limits
   - modalities
   - constraints
   - declared execution surfaces

3. request-mode normalization belongs in planner modules
   - `ExecutionMode`
   - intent mapping
   - mode-hint classification

4. policy-rule evaluation belongs in planner policy modules
   - five-scope rule ordering
   - surface preference
   - fallback selection
   - timeout and session defaults

5. plan assembly belongs in planner modules
   - chosen surface
   - normalized parameters
   - fallback surfaces
   - adapter refs

6. semantic API concerns belong in semantic protocol modules
   - API-family payload meaning
   - canonical event decoding
   - finish reasons
   - usage extraction

7. transport-facing envelopes belong in wire-format modules
   - relative routes
   - content types
   - client event wrappers
   - raw frame parsing

8. HTTP, SSE, and WebSocket mechanics belong in transport modules
   - framing
   - connect and disconnect behavior
   - reconnect
   - backpressure

9. continuation and persistence concerns belong in session runtime modules
   - continuation ids
   - socket reuse
   - stale-session fallback

10. imperative quirks belong in layer-scoped adapters
    - preferably plan adapters first
    - never as omniscient global hooks

11. compat-only expectations belong in compat analyzers or compat expectations
    - they must not patch runtime behavior

12. issue drafting and filing belongs in compat tooling
    - not in provider, planner, protocol, wire-format, transport, or session runtime code

## Source Layout Principle

If a live pressure test finds an anomaly, a contributor should be able to answer two questions quickly:

1. which architectural layer owns this problem
2. where in the source tree should the fix or expectation live

If the answer is unclear, the architecture is still too blurry.
