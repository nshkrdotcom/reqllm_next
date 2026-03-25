---
id: reqllm.decision.live_verifier_tests
status: accepted
date: 2026-03-25
affects:
  - reqllm.package
  - reqllm.model_compat
  - reqllm.workflow
---

# Replay by Default, Live Verifiers by Exception

## Context

ReqLlmNext uses recorded fixtures as first-class evidence for the public API,
scenario lanes, provider feature probes, and provider coverage sweeps.

That replay-first model keeps the package deterministic, cheap to run, and
reviewable. It is also the right default for CI.

At the same time, a fixture-only posture is not enough for a package that is
trying to stay honest about provider drift, beta flags, versioned tool
surfaces, and native media behavior. The package still needs real provider
checks somewhere.

Running broad live suites in CI is not a good fit. Those runs are expensive,
credential-dependent, rate-limit-sensitive, and prone to failing for reasons
that do not reflect local regressions in ReqLlmNext.

## Decision

ReqLlmNext keeps fixtures as the default proof system and treats live provider
tests as a separate sparse verifier lane.

The verifier lane should follow these rules:

1. live verifier tests are opt-in and never required for routine CI
2. live verifier tests are intentionally sparse and high-signal
3. live verifier tests exist to check provider drift, validate current
   integration behavior, and support deliberate fixture refresh work
4. replay-backed coverage remains the default proof path for public API,
   scenario, model-slice, coverage, and most provider-feature tests
5. provider-owned utility endpoints may rely on request-execution harness proof
   when live provider behavior is not the main risk

ReqLlmNext should expose an explicit command path for the live verifier lane
instead of asking contributors to infer it from fixture-record mode alone.

## Consequences

The package can keep CI fast and deterministic without pretending that replayed
fixtures are the whole integration story.

Provider drift checks become clearer because live verifier tests are explicit
about being sparse integration checks instead of masquerading as routine test
coverage.

Fixture refresh work remains intentional rather than accidental, and the repo
can distinguish between:

1. replay-backed tests
2. live verifier tests
3. request-harness utility tests
