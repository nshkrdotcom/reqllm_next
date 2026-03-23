# Diagnostics Spec

Status: Proposed

## Objective

Define the structured diagnostic surface needed for live model compatibility runs, anomaly attribution, and issue drafting.

## Purpose

The project needs diagnostics because a compatibility system is only sustainable if failures can be attributed to the correct architectural layer.

Without structured diagnostics, pressure testing collapses into vague "model failed" results.

## Core Rule

Diagnostics are observational. They must describe runtime behavior without mutating it.

Diagnostics should be emitted from runtime layers, but consumed by compat and issue-filing systems outside those layers.

## Diagnostic Domains

1. model profile diagnostics
   - normalized model source information
   - override application summary
   - resolved operations and features

2. planner diagnostics
   - operation-family selection
   - stream mode selection
   - protocol choice
   - transport choice
   - session choice
   - fallback policy

3. semantic protocol diagnostics
   - outbound route or target
   - protocol headers
   - decode anomalies
   - unexpected event shapes or ordering
   - terminal metadata extraction

4. transport diagnostics
   - connect and disconnect events
   - framing and parse failures
   - timeouts
   - retries and reconnects
   - lifecycle transitions

5. session diagnostics
   - continuation ids
   - in-flight transitions
   - reconnect fallback
   - invalid continuation behavior

6. provider diagnostics
   - auth style used
   - endpoint root used
   - provider-specific non-secret headers

## Canonical Shapes

```elixir
%DiagnosticEvent{
  layer: atom(),
  event: atom(),
  severity: :debug | :info | :warning | :error,
  data: map()
}

%AnomalyReport{
  layer: atom(),
  type: atom(),
  summary: binary(),
  evidence: map(),
  related_events: [DiagnosticEvent.t()]
}
```

## Requirements

1. diagnostics must be structured, not free-form text blobs
2. diagnostics must avoid leaking secrets or raw credentials
3. diagnostics must be stable enough for compat analyzers to consume
4. diagnostics must be attributable to one layer by default
5. diagnostics must support live pressure tests and issue drafting

## Consumption Rule

Runtime layers emit diagnostics. Compat tooling classifies them. Issue filing consumes the classified output.

That separation prevents testing and issue logic from leaking back into execution code.

The runtime-facing event contract for diagnostics that leave execution code is defined in [telemetry.md](/Users/mhostetler/Source/ReqLLM/reqllm_next/specs/telemetry.md).
