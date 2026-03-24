defmodule ReqLlmNext.ProviderTest.Comprehensive do
  @moduledoc """
  Comprehensive per-model provider tests for ReqLlmNext v2.

  Uses the scenario system to generate tests based on model capabilities.
  Each scenario determines its own applicability and runs its own tests.

  Tests use fixtures for fast, deterministic execution while supporting
  live API recording with REQ_LLM_NEXT_FIXTURES_MODE=record.

  ## Usage

      defmodule ReqLlmNext.Coverage.OpenAI.ComprehensiveTest do
        use ReqLlmNext.ProviderTest.Comprehensive,
          provider: :openai,
          models: ["openai:gpt-4o-mini", "openai:gpt-4o"]
      end

  """

  @doc """
  Returns curated coverage entries for a provider.
  """
  def entries_for_provider(provider, group \\ :coverage) do
    ReqLlmNext.SupportMatrix.entries(provider, group)
  end

  defmacro __using__(opts) do
    provider = Keyword.fetch!(opts, :provider)
    entries = Keyword.get(opts, :entries)
    group = Keyword.get(opts, :group, :coverage)

    quote bind_quoted: [provider: provider, entries: entries, group: group] do
      use ExUnit.Case, async: false

      import ExUnit.Case

      @moduletag :coverage
      @moduletag provider: to_string(provider)
      @moduletag timeout: 300_000

      @provider provider
      @entries entries ||
                 ReqLlmNext.ProviderTest.Comprehensive.entries_for_provider(provider, group)

      setup_all do
        LLMDB.load(allow: :all, custom: %{})
        :ok
      end

      for entry <- @entries do
        @entry entry
        @model_spec entry.spec
        @scenario_ids entry.scenarios
        @run_opts entry.opts

        describe "#{entry.spec}" do
          @describetag model: entry.spec |> String.split(":", parts: 2) |> List.last()
          @describetag lane: entry.lane
          @describetag group: entry.group

          {:ok, model} = LLMDB.model(entry.spec)

          scenarios =
            model
            |> ReqLlmNext.Scenarios.for_model()
            |> Enum.filter(&(&1.id() in entry.scenarios))

          for scenario_mod <- scenarios do
            @scenario_mod scenario_mod
            @tag scenario: scenario_mod.id()

            test scenario_mod.name() do
              {:ok, model} = LLMDB.model(unquote(entry.spec))
              result = unquote(scenario_mod).run(unquote(entry.spec), model, unquote(entry.opts))

              assert result.status == :ok,
                     """
                     Scenario :#{unquote(scenario_mod).id()} failed for #{unquote(entry.spec)}

                     Error: #{inspect(result.error)}

                     Steps: #{inspect(result.steps, pretty: true)}
                     """
            end
          end
        end
      end
    end
  end
end
