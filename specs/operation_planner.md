# Operation Planner Spec

Status: Proposed

<!-- covers: reqllm.execution_plan.planner_owns_assembly -->

## Objective

Define the planner boundary that turns `ModelProfile`, `ExecutionMode`, and policy rules into one fully resolved `ExecutionPlan`.

## Purpose

The planner is the only layer allowed to interpret model facts, mode facts, and policy rules together.

It owns:

1. mode normalization
2. rule evaluation
3. surface selection
4. parameter normalization
5. fallback planning
6. adapter selection

Downstream execution layers must receive a resolved plan, not raw capability data or half-finished defaults.

## Responsibilities

1. Accept API intent, prompt/context, `ModelProfile`, request mode hints, generation parameters, and optional session references.
2. Normalize intent and mode hints into `ExecutionMode`.
3. Evaluate ordered policy rules across provider, family, model, operation, and mode scopes.
4. Select one supported `ExecutionSurface`.
5. Merge generation parameters with stable defaults and normalize them against constraints.
6. Build one canonical `ExecutionPlan`.
7. Produce structured errors when no valid plan can be formed.

## Recommended Internal Decomposition

1. `IntentNormalizer`
   - maps public API verbs onto operation families

2. `ModeNormalizer`
   - turns mode-affecting hints into `ExecutionMode`

3. `PolicyResolver`
   - evaluates ordered match-and-patch rules

4. `SurfaceSelector`
   - chooses one surface plus fallback surfaces from the supported catalog

5. `ParameterNormalizer`
   - applies stable defaults and request-scoped constraints

6. `SessionPlanner`
   - resolves attach, create, continue, or stateless strategy

7. `AdapterSelector`
   - resolves layer-scoped adapter refs for the final plan

These may be separate modules or pure functions, but the architectural boundary is still one planner.

## Planner Ownership Rules

The planner alone may:

1. choose a surface
2. choose fallback order
3. interpret `ExecutionMode`
4. combine rules from multiple scopes
5. decide whether the request should use a persistent session

The planner must not:

1. encode provider payloads
2. open sockets
3. send HTTP requests
4. decode provider events

## Common Plan Assembly Order

1. Resolve `ModelProfile`.
2. Normalize `ExecutionMode`.
3. Resolve matching policy rules.
4. Select one primary `ExecutionSurface`.
5. Select fallback surfaces if any.
6. Merge and normalize generation parameters.
7. Build session strategy and timeout strategy.
8. Attach plan-aware adapters.
9. Emit the final `ExecutionPlan`.

## Example: `openai:gpt-5-codex`

For a tool-heavy streaming text request with persistent session preference:

1. `ExecutionMode` says `operation: :text`, `stream?: true`, `tools?: true`, `session: :preferred`
2. policy rules prefer `:responses_ws_text`
3. the surface selector confirms that surface exists in `ModelProfile`
4. the planner chooses WebSocket as primary and Responses-over-HTTP as fallback
5. the final plan carries one chosen surface, one fallback set, normalized parameters, and plan adapters
