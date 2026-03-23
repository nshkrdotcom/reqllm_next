# Policy Rules and Adapters Spec

Status: Proposed

<!-- covers: reqllm.policy_rules.five_scopes reqllm.policy_rules.match_patch reqllm.policy_rules.capability_safe -->

## Objective

Define how ReqLlmNext resolves behavior declaratively across five scopes and where imperative adapter patches are still allowed.

## Purpose

The earlier deep-merge override model is not expressive enough for:

1. very specific model and mode combinations
2. surface selection across multiple endpoint styles
3. fallback and timeout choices that depend on request mode

ReqLlmNext v2 should use ordered policy rules, not only nested override maps.

## Five Policy Scopes

Policy rules resolve in this order:

1. provider
2. family
3. model
4. operation
5. mode

Later scopes are more specific and may refine earlier choices. Within a scope, declaration order must be deterministic.

## Match-and-Patch Shape

```elixir
%PolicyRule{
  id: :gpt5_codex_tools_session,
  scope: :mode,
  match: %{
    provider: :openai,
    family: "gpt-5",
    model: "openai:gpt-5-codex",
    operation: :text,
    mode: %{
      stream?: true,
      tools?: true,
      session: :preferred
    }
  },
  patch: %{
    preferred_surfaces: [:responses_ws_text, :responses_http_text],
    fallback_surfaces: [:responses_http_text],
    timeout_class: :long_running,
    session_strategy: %{mode: :attach_or_create},
    parameter_defaults: %{reasoning_effort: :high},
    plan_adapters: [ReqLlmNext.Adapters.OpenAI.Reasoning]
  }
}
```

## Allowed Patch Domains

Rules may patch:

1. preferred surfaces
2. fallback surfaces
3. timeout class
4. session strategy defaults
5. stable parameter defaults for this mode
6. plan-adapter refs

Rules may not patch:

1. model identity
2. provider identity
3. unsupported operation support
4. unsupported surface support
5. raw payloads or transport handles

## Capability-Safety Rule

Policy rules may only choose among behavior already supported by `ModelProfile`.

They must not invent:

1. a surface absent from the profile
2. a feature absent from the profile
3. a session capability absent from the profile

Rules select and refine. They do not create support.

## Request Decomposition Rule

Public request input must be split into two categories before rule resolution:

1. mode hints
   - affect `ExecutionMode`
   - examples: stream, tool use, structured output, session preference, latency class

2. generation parameters
   - affect payload content after a surface is chosen
   - examples: temperature, max output tokens, stop sequences

Mode hints are normalized before policy rules run. Generation parameters are normalized after surface selection.

## Adapter Rule

Adapters remain the imperative escape hatch, but they must be layer-scoped.

ReqLlmNext v2 starts with `PlanAdapter` as the primary adapter type:

```elixir
@callback patch(ExecutionPlan.t()) :: {:ok, ExecutionPlan.t()} | {:error, term()}
```

Future adapter kinds are allowed only if they are explicit and owned by one layer, such as a protocol-specific adapter. A global raw-model adapter pipeline is not part of the target design.

## Example Resolution Order

For `openai:gpt-5-codex` text generation:

1. provider rule may prefer chat-style HTTP for simple OpenAI text calls
2. family rule may prefer Responses surfaces for `gpt-5`
3. model rule may increase timeout class for `gpt-5-codex`
4. operation rule may prefer object-capable surfaces for `:object`
5. mode rule may switch a tool-heavy persistent request to WebSocket

The final chosen behavior is the result of all matching rules, not one nested override map.
