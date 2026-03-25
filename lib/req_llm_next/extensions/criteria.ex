defmodule ReqLlmNext.Extensions.Criteria do
  @moduledoc """
  Declarative match criteria for extension families and rules.
  """

  @derive Jason.Encoder

  @schema Zoi.struct(
            __MODULE__,
            %{
              provider_ids: Zoi.array(Zoi.atom()) |> Zoi.default([]),
              family_ids: Zoi.array(Zoi.atom()) |> Zoi.default([]),
              model_ids: Zoi.array(Zoi.string()) |> Zoi.default([]),
              operations:
                Zoi.array(Zoi.enum([:text, :object, :embed, :image, :transcription, :speech]))
                |> Zoi.default([]),
              transports: Zoi.array(Zoi.atom()) |> Zoi.default([]),
              semantic_protocols: Zoi.array(Zoi.atom()) |> Zoi.default([]),
              stream?: Zoi.boolean() |> Zoi.nullish() |> Zoi.default(nil),
              tools?: Zoi.boolean() |> Zoi.nullish() |> Zoi.default(nil),
              structured?: Zoi.boolean() |> Zoi.nullish() |> Zoi.default(nil),
              facts: Zoi.map() |> Zoi.default(%{}),
              features: Zoi.map() |> Zoi.default(%{})
            },
            coerce: true
          )

  @type t :: %__MODULE__{
          __spark_metadata__: map() | nil,
          provider_ids: [atom()],
          family_ids: [atom()],
          model_ids: [String.t()],
          operations: [atom()],
          transports: [atom()],
          semantic_protocols: [atom()],
          stream?: boolean() | nil,
          tools?: boolean() | nil,
          structured?: boolean() | nil,
          facts: map(),
          features: map()
        }

  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct [__spark_metadata__: nil] ++ Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema

  @spec new(map()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_map(attrs), do: Zoi.parse(@schema, attrs)

  @spec new!(map()) :: t()
  def new!(attrs) when is_map(attrs) do
    case new(attrs) do
      {:ok, criteria} -> criteria
      {:error, reason} -> raise ArgumentError, "Invalid extension criteria: #{inspect(reason)}"
    end
  end

  @spec matches?(t(), map()) :: boolean()
  def matches?(%__MODULE__{} = criteria, context) when is_map(context) do
    provider_match?(criteria.provider_ids, context[:provider]) and
      family_match?(criteria.family_ids, context[:family]) and
      model_match?(criteria.model_ids, context[:model_id]) and
      operation_match?(criteria.operations, context[:operation]) and
      transport_match?(criteria.transports, context[:transport]) and
      protocol_match?(criteria.semantic_protocols, context[:semantic_protocol]) and
      boolean_match?(criteria.stream?, context[:stream?]) and
      boolean_match?(criteria.tools?, context[:tools?]) and
      boolean_match?(criteria.structured?, context[:structured?]) and
      map_subset?(criteria.facts, context[:facts]) and
      map_subset?(criteria.features, context[:features])
  end

  @spec specificity(t()) :: non_neg_integer()
  def specificity(%__MODULE__{} = criteria) do
    Enum.sum([
      list_weight(criteria.provider_ids),
      list_weight(criteria.family_ids),
      list_weight(criteria.model_ids),
      list_weight(criteria.operations),
      list_weight(criteria.transports),
      list_weight(criteria.semantic_protocols),
      boolean_weight(criteria.stream?),
      boolean_weight(criteria.tools?),
      boolean_weight(criteria.structured?),
      map_size(criteria.facts),
      map_size(criteria.features)
    ])
  end

  @spec merge(t(), t()) :: t()
  def merge(%__MODULE__{} = parent, %__MODULE__{} = child) do
    %__MODULE__{
      provider_ids: inherited_or_override(parent.provider_ids, child.provider_ids),
      family_ids: inherited_or_override(parent.family_ids, child.family_ids),
      model_ids: inherited_or_override(parent.model_ids, child.model_ids),
      operations: inherited_or_override(parent.operations, child.operations),
      transports: inherited_or_override(parent.transports, child.transports),
      semantic_protocols:
        inherited_or_override(parent.semantic_protocols, child.semantic_protocols),
      stream?: inherited_boolean(parent.stream?, child.stream?),
      tools?: inherited_boolean(parent.tools?, child.tools?),
      structured?: inherited_boolean(parent.structured?, child.structured?),
      facts: deep_merge(parent.facts, child.facts),
      features: deep_merge(parent.features, child.features)
    }
  end

  defp provider_match?([], _provider), do: true
  defp provider_match?(_providers, nil), do: false
  defp provider_match?(providers, provider), do: provider in providers

  defp family_match?([], _family), do: true
  defp family_match?(_families, nil), do: false
  defp family_match?(families, family), do: family in families

  defp model_match?([], _model_id), do: true
  defp model_match?(_model_ids, nil), do: false
  defp model_match?(model_ids, model_id), do: model_id in model_ids

  defp operation_match?([], _operation), do: true
  defp operation_match?(_operations, nil), do: false
  defp operation_match?(operations, operation), do: operation in operations

  defp transport_match?([], _transport), do: true
  defp transport_match?(_transports, nil), do: false
  defp transport_match?(transports, transport), do: transport in transports

  defp protocol_match?([], _semantic_protocol), do: true
  defp protocol_match?(_protocols, nil), do: false
  defp protocol_match?(protocols, semantic_protocol), do: semantic_protocol in protocols

  defp boolean_match?(nil, _actual), do: true
  defp boolean_match?(expected, actual), do: expected == actual

  defp map_subset?(expected, _actual) when expected == %{}, do: true
  defp map_subset?(_expected, nil), do: false

  defp map_subset?(expected, actual) when is_map(expected) and is_map(actual) do
    Enum.all?(expected, fn {key, value} ->
      case {value, Map.get(actual, key)} do
        {%{} = nested_expected, %{} = nested_actual} ->
          map_subset?(nested_expected, nested_actual)

        _ ->
          Map.get(actual, key) == value
      end
    end)
  end

  defp list_weight([]), do: 0
  defp list_weight(list), do: length(list)

  defp boolean_weight(nil), do: 0
  defp boolean_weight(_value), do: 1

  defp inherited_or_override(parent, []), do: parent
  defp inherited_or_override(_parent, child), do: child

  defp inherited_boolean(parent, nil), do: parent
  defp inherited_boolean(_parent, child), do: child

  defp deep_merge(left, right) when left == %{}, do: right
  defp deep_merge(left, right) when right == %{}, do: left

  defp deep_merge(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, fn _key, left_value, right_value ->
      if is_map(left_value) and is_map(right_value) do
        deep_merge(left_value, right_value)
      else
        right_value
      end
    end)
  end
end
