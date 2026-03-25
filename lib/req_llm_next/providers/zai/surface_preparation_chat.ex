defmodule ReqLlmNext.SurfacePreparation.ZAIChat do
  @moduledoc """
  Z.AI chat surface-owned request preparation.
  """

  alias ReqLlmNext.ExecutionSurface

  @spec prepare(ExecutionSurface.t(), term(), keyword()) :: {:ok, keyword()}
  def prepare(%ExecutionSurface{}, _prompt, opts) do
    provider_options =
      opts
      |> Keyword.get(:provider_options, [])
      |> normalize_provider_options()

    thinking =
      Keyword.get(opts, :thinking) || Keyword.get(provider_options, :thinking)

    normalized_opts =
      opts
      |> Keyword.put(:provider_options, Keyword.delete(provider_options, :thinking))
      |> maybe_put(:thinking, thinking)
      |> normalize_tool_choice()

    {:ok, normalized_opts}
  end

  @spec validate(ExecutionSurface.t(), keyword()) :: :ok | {:error, term()}
  def validate(%ExecutionSurface{}, opts) do
    ReqLlmNext.SurfacePreparation.validate_canonical_inputs(opts)
  end

  defp normalize_provider_options(opts) when is_map(opts), do: Map.to_list(opts)
  defp normalize_provider_options(opts) when is_list(opts), do: opts
  defp normalize_provider_options(_opts), do: []

  defp normalize_tool_choice(opts) do
    case Keyword.get(opts, :tool_choice) do
      %{name: _name, type: _type} ->
        Keyword.put(opts, :tool_choice, "auto")

      %{type: "function", function: %{name: _name}} ->
        Keyword.put(opts, :tool_choice, "auto")

      %{"type" => "function", "function" => %{"name" => _name}} ->
        Keyword.put(opts, :tool_choice, "auto")

      _ ->
        opts
    end
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
