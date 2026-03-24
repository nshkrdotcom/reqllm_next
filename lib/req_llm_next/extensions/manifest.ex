defmodule ReqLlmNext.Extensions.Manifest do
  @moduledoc """
  Deterministic manifest of providers, default execution families, and override rules.
  """

  alias ReqLlmNext.Extensions.{Criteria, Family, Provider, Rule}

  @derive Jason.Encoder

  @schema Zoi.struct(
            __MODULE__,
            %{
              providers: Zoi.map() |> Zoi.default(%{}),
              families: Zoi.array(Zoi.any()) |> Zoi.default([]),
              rules: Zoi.array(Zoi.any()) |> Zoi.default([])
            },
            coerce: true
          )

  @type t :: %__MODULE__{
          providers: %{optional(atom()) => Provider.t()},
          families: [Family.t()],
          rules: [Rule.t()]
        }

  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema

  @spec new(map()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_map(attrs) do
    attrs = %{
      providers: normalize_providers(Map.get(attrs, :providers, %{})),
      families: normalize_entities(Map.get(attrs, :families, []), Family),
      rules: normalize_entities(Map.get(attrs, :rules, []), Rule)
    }

    Zoi.parse(@schema, attrs)
  end

  @spec new!(map()) :: t()
  def new!(attrs) when is_map(attrs) do
    case new(attrs) do
      {:ok, manifest} -> manifest
      {:error, reason} -> raise ArgumentError, "Invalid extension manifest: #{inspect(reason)}"
    end
  end

  @spec resolve_family(t(), map()) :: {:ok, Family.t()} | {:error, :no_matching_family}
  def resolve_family(%__MODULE__{families: families}, context) when is_map(context) do
    families
    |> Enum.with_index()
    |> Enum.filter(fn {family, _index} -> Criteria.matches?(family.criteria, context) end)
    |> Enum.sort_by(fn {family, index} ->
      {-family.priority, -Criteria.specificity(family.criteria), (family.default? && 1) || 0,
       index}
    end)
    |> case do
      [{family, _index} | _rest] -> {:ok, family}
      [] -> {:error, :no_matching_family}
    end
  end

  @spec matching_rules(t(), map()) :: [Rule.t()]
  def matching_rules(%__MODULE__{rules: rules}, context) when is_map(context) do
    rules
    |> Enum.with_index()
    |> Enum.filter(fn {rule, _index} -> Criteria.matches?(rule.criteria, context) end)
    |> Enum.sort_by(fn {rule, index} ->
      {rule.priority, Criteria.specificity(rule.criteria), index}
    end)
    |> Enum.map(&elem(&1, 0))
  end

  defp normalize_entities(items, module) when is_list(items) do
    Enum.map(items, fn
      %^module{} = item -> item
      item when is_map(item) -> module.new!(item)
    end)
  end

  defp normalize_providers(items) when is_map(items) do
    Enum.into(items, %{}, fn {id, provider} ->
      provider =
        case provider do
          %Provider{} = provider -> provider
          provider when is_map(provider) -> Provider.new!(Map.put_new(provider, :id, id))
        end

      {id, provider}
    end)
  end

  defp normalize_providers(items) when is_list(items) do
    Enum.into(items, %{}, fn
      %Provider{id: id} = provider ->
        {id, provider}

      provider when is_map(provider) ->
        provider = Provider.new!(provider)
        {provider.id, provider}
    end)
  end
end
