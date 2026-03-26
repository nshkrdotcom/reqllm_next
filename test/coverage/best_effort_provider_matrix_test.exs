defmodule ReqLlmNext.BestEffortProviderMatrixTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.{
    ExecutionModules,
    ModelProfile,
    OperationPlanner,
    Provider,
    RuntimeMetadata
  }

  alias ReqLlmNext.Providers.Generic

  @providers [
    %{
      id: :mistral,
      env: "MISTRAL_API_KEY",
      expected_url: "https://api.mistral.ai/v1/chat/completions",
      runtime_opts: []
    },
    %{
      id: :togetherai,
      env: "TOGETHER_API_KEY",
      expected_url: "https://api.together.xyz/v1/chat/completions",
      runtime_opts: []
    },
    %{
      id: :github_models,
      env: "GITHUB_TOKEN",
      expected_url: "https://models.github.ai/inference/chat/completions",
      runtime_opts: []
    },
    %{
      id: :perplexity,
      env: "PERPLEXITY_API_KEY",
      expected_url: "https://api.perplexity.ai/chat/completions",
      runtime_opts: []
    },
    %{
      id: :cloudflare_workers_ai,
      env: "CLOUDFLARE_API_KEY",
      expected_url: "https://api.cloudflare.com/client/v4/accounts/test-account/ai/v1/chat/completions",
      runtime_opts: [account_id: "test-account"]
    }
  ]

  for %{id: provider_id} = provider <- @providers do
    test "plans generic best-effort execution for #{provider_id}" do
      provider = unquote(Macro.escape(provider))
      model = best_effort_model!(provider.id)

      assert ReqLlmNext.support_status(model) == :best_effort
      assert RuntimeMetadata.primary_family(model) == :openai_chat_compatible

      {:ok, profile} = ModelProfile.from_model(model)

      assert profile.family == :openai_chat_compatible

      assert [%{id: :openai_chat_text_http_sse, family: :openai_chat_compatible}] =
               ModelProfile.surfaces_for(profile, :text)

      assert {:ok, plan} = OperationPlanner.plan(model, :text, "Hello", stream?: true)

      assert plan.provider == provider.id
      assert plan.surface.id == :openai_chat_text_http_sse
      assert plan.surface.family == :openai_chat_compatible
      assert plan.semantic_protocol == :openai_chat
      assert plan.wire_format == :openai_chat_sse_json
      assert plan.transport == :http_sse

      assert %{
               provider_mod: Generic,
               session_runtime_mod: ReqLlmNext.SessionRuntimes.None,
               protocol_mod: ReqLlmNext.SemanticProtocols.OpenAIChat,
               wire_mod: ReqLlmNext.Wire.OpenAIChat,
               transport_mod: ReqLlmNext.Transports.HTTPStream
             } = ExecutionModules.resolve(plan)
    end

    test "builds generic runtime request details for #{provider_id}" do
      provider = unquote(Macro.escape(provider))
      model = best_effort_model!(provider.id)
      {:ok, runtime} = RuntimeMetadata.provider_runtime(model)
      {:ok, execution_entry} = RuntimeMetadata.execution_entry(model, :text)

      System.put_env(provider.env, "test-best-effort-key")

      on_exit(fn ->
        System.delete_env(provider.env)
      end)

      opts =
        [
          _use_runtime_metadata: true,
          _provider_runtime: runtime,
          _model_execution_entry: execution_entry
        ] ++ provider.runtime_opts

      assert {:ok, url} = Provider.request_url(Generic, model, "/unused", opts)
      assert url == provider.expected_url

      assert {:ok, headers} =
               Provider.request_headers(Generic, model, opts, [{"Content-Type", "application/json"}])

      assert {"Authorization", "Bearer test-best-effort-key"} in headers
      assert {"Content-Type", "application/json"} in headers
    end
  end

  defp best_effort_model!(provider) do
    provider
    |> LLMDB.models()
    |> Enum.find(&(ReqLlmNext.support_status(&1) == :best_effort))
    |> case do
      %LLMDB.Model{} = model -> model
      nil -> flunk("expected a best-effort model for #{inspect(provider)}")
    end
  end
end
