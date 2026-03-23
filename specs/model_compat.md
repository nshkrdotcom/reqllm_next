# Model Compat Spec

Status: Proposed

## Objective

Define the live model compatibility and pressure-test system as a first-class consumer of the ReqLlmNext architecture.

## Purpose

ReqLlmNext should not only execute model requests. It should also support a comprehensive model compatibility system that can:

1. run shared live scenarios against allow-listed models
2. pressure-test real provider behavior
3. detect anomalies and regressions
4. classify failures by architectural layer
5. produce structured issue drafts for GitHub when anomalies are significant

This is an advanced integration-testing system built on top of the same runtime contracts as normal execution.

## Core Rule

Model compat must consume the same architecture as runtime execution.

It must not:

1. bypass model normalization
2. bypass planning
3. bypass protocol or transport layers
4. patch runtime behavior for the sake of tests

The value of the compat system is that it exercises the real layered system.

## Scope

Model compat covers:

1. common text-generation scenarios
2. streaming scenarios
3. object generation scenarios
4. tool-calling scenarios
5. embeddings scenarios
6. protocol and transport edge cases when allow-listed
7. session and continuation pressure tests when supported by the model and provider

## Canonical Shapes

```elixir
%CompatRun{
  id: binary(),
  model_spec: binary(),
  profile: ModelProfile.t(),
  scenarios: [ScenarioResult.t()],
  anomalies: [Anomaly.t()],
  status: :ok | :warning | :failed
}

%ScenarioResult{
  scenario_id: atom(),
  status: :ok | :warning | :failed,
  layer: atom() | nil,
  evidence: map(),
  anomalies: [Anomaly.t()]
}

%Anomaly{
  type: atom(),
  severity: :low | :medium | :high,
  layer: :model_profile | :planner | :semantic_protocol | :transport | :session_runtime | :provider | :adapter,
  summary: binary(),
  evidence: map(),
  issue_candidate?: boolean()
}

%IssueDraft{
  title: binary(),
  body: binary(),
  labels: [binary()],
  model_spec: binary(),
  scenarios: [atom()],
  anomalies: [Anomaly.t()]
}
```

## Scenario Model

Scenarios should be:

1. shared and reusable
2. macro-driven where that reduces boilerplate
3. applicable based on `ModelProfile`
4. expressive enough to cover common provider behaviors without embedding model-specific hacks

A scenario should declare:

1. what operation family it exercises
2. whether streaming is required
3. whether tools or session support are required
4. what counts as success, warning, or failure
5. what layer an anomaly should default to when it fails

## Pressure-Test Runner

The live pressure-test runner should:

1. run only against allow-listed models or environments
2. use real provider APIs
3. capture structured diagnostics from the execution stack
4. support retries or repeated sampling where appropriate
5. classify anomalies before deciding whether an issue should be drafted or filed

The runner is not a generic benchmark system. Its purpose is compatibility verification and anomaly discovery.

## Issue Filing

Issue filing should be built on structured evidence, not ad hoc log dumps.

The system may:

1. prepare an issue draft automatically
2. deduplicate or check for likely existing issues
3. file an issue when explicitly requested or policy-allowed

The system must not file issues from raw runtime exceptions without classification.

An issue draft should include:

1. model spec
2. scenario ids
3. layer attribution
4. concise anomaly summary
5. sanitized evidence from diagnostics
6. reproduction notes when possible

## Relationship To Runtime Layers

Model compat should use the same canonical inputs and outputs as normal execution:

1. `model_input`
2. `%ModelProfile{}`
3. `%ExecutionPlan{}`
4. protocol outputs
5. transport signals
6. session updates
7. structured diagnostics

Compat-specific expectations belong in compat code. They do not belong in runtime layers.

## Non-Goals

1. patching runtime behavior to make compat scenarios pass
2. scattering model-specific expectations through runtime execution code
3. using issue filing as a substitute for anomaly classification
4. turning compat runs into a benchmark or leaderboard system
