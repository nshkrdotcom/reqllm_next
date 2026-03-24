defmodule ReqLlmNext.Extensions.Seams do
  @moduledoc """
  Narrow override seams available to extension families and rules.
  """

  @derive Jason.Encoder

  @schema Zoi.struct(
            __MODULE__,
            %{
              provider_module: Zoi.any() |> Zoi.nullish() |> Zoi.default(nil),
              provider_facts_module: Zoi.any() |> Zoi.nullish() |> Zoi.default(nil),
              surface_catalog_module: Zoi.any() |> Zoi.nullish() |> Zoi.default(nil),
              surface_preparation_modules: Zoi.map() |> Zoi.default(%{}),
              semantic_protocol_modules: Zoi.map() |> Zoi.default(%{}),
              wire_modules: Zoi.map() |> Zoi.default(%{}),
              transport_modules: Zoi.map() |> Zoi.default(%{}),
              adapter_modules: Zoi.array(Zoi.any()) |> Zoi.default([]),
              utility_modules: Zoi.map() |> Zoi.default(%{})
            },
            coerce: true
          )

  @type t :: %__MODULE__{
          __spark_metadata__: map() | nil,
          provider_module: module() | nil,
          provider_facts_module: module() | nil,
          surface_catalog_module: module() | nil,
          surface_preparation_modules: map(),
          semantic_protocol_modules: map(),
          wire_modules: map(),
          transport_modules: map(),
          adapter_modules: [module()],
          utility_modules: map()
        }

  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct [__spark_metadata__: nil] ++ Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema

  @spec new(map()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_map(attrs), do: Zoi.parse(@schema, attrs)

  @spec new!(map()) :: t()
  def new!(attrs) when is_map(attrs) do
    case new(attrs) do
      {:ok, seams} -> seams
      {:error, reason} -> raise ArgumentError, "Invalid extension seams: #{inspect(reason)}"
    end
  end

  @spec merge(t(), t()) :: t()
  def merge(%__MODULE__{} = left, %__MODULE__{} = right) do
    %__MODULE__{
      provider_module: right.provider_module || left.provider_module,
      provider_facts_module: right.provider_facts_module || left.provider_facts_module,
      surface_catalog_module: right.surface_catalog_module || left.surface_catalog_module,
      surface_preparation_modules:
        Map.merge(left.surface_preparation_modules, right.surface_preparation_modules),
      semantic_protocol_modules:
        Map.merge(left.semantic_protocol_modules, right.semantic_protocol_modules),
      wire_modules: Map.merge(left.wire_modules, right.wire_modules),
      transport_modules: Map.merge(left.transport_modules, right.transport_modules),
      adapter_modules: left.adapter_modules ++ right.adapter_modules,
      utility_modules: Map.merge(left.utility_modules, right.utility_modules)
    }
  end

  @spec empty() :: t()
  def empty, do: new!(%{})
end
