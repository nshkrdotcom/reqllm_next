defmodule ReqLlmNext.Extensions.Dsl.Normalize do
  @moduledoc false

  alias ReqLlmNext.Extensions.{Criteria, Family, Provider, Rule, Seams}

  @spec provider(Provider.t()) :: {:ok, Provider.t()} | {:error, term()}
  def provider(%Provider{} = provider) do
    provider
    |> Map.from_struct()
    |> Map.drop([:__spark_metadata__])
    |> keywords_to_maps([
      :surface_preparation_modules,
      :semantic_protocol_modules,
      :wire_modules,
      :transport_modules,
      :utility_modules
    ])
    |> Provider.new()
  end

  @spec family(Family.t()) :: {:ok, Family.t()} | {:error, term()}
  def family(%Family{} = family) do
    family
    |> Map.from_struct()
    |> Map.drop([:__spark_metadata__])
    |> Family.new()
  end

  @spec rule(Rule.t()) :: {:ok, Rule.t()} | {:error, term()}
  def rule(%Rule{} = rule) do
    rule
    |> Map.from_struct()
    |> Map.drop([:__spark_metadata__])
    |> Rule.new()
  end

  @spec match(Criteria.t()) :: {:ok, Criteria.t()} | {:error, term()}
  def match(%Criteria{} = criteria) do
    criteria
    |> Map.from_struct()
    |> Map.drop([:__spark_metadata__])
    |> keywords_to_maps([:facts, :features])
    |> Criteria.new()
  end

  @spec register(Seams.t()) :: {:ok, Seams.t()} | {:error, term()}
  def register(%Seams{} = seams) do
    normalize_seams(seams)
  end

  @spec stack(Seams.t()) :: {:ok, Seams.t()} | {:error, term()}
  def stack(%Seams{} = seams) do
    normalize_seams(seams)
  end

  @spec patch(Seams.t()) :: {:ok, Seams.t()} | {:error, term()}
  def patch(%Seams{} = seams) do
    normalize_seams(seams)
  end

  defp normalize_seams(%Seams{} = seams) do
    seams
    |> Map.from_struct()
    |> Map.drop([:__spark_metadata__])
    |> keywords_to_maps([
      :surface_preparation_modules,
      :semantic_protocol_modules,
      :wire_modules,
      :transport_modules,
      :utility_modules
    ])
    |> Seams.new()
  end

  defp keywords_to_maps(map, keys) do
    Enum.reduce(keys, map, fn key, acc ->
      case Map.get(acc, key) do
        value ->
          if is_list(value) and Keyword.keyword?(value) do
            Map.put(acc, key, keyword_to_map(value))
          else
            acc
          end
      end
    end)
  end

  defp keyword_to_map(keyword) do
    Enum.into(keyword, %{}, fn {key, value} ->
      normalized =
        if is_list(value) and Keyword.keyword?(value) do
          keyword_to_map(value)
        else
          value
        end

      {key, normalized}
    end)
  end
end
