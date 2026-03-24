defmodule ReqLlmNext.Extensions.Provider do
  @moduledoc """
  Provider registration declaration consumed by the extension manifest.
  """

  alias ReqLlmNext.Extensions.Seams

  @derive Jason.Encoder

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.atom(),
              default_family: Zoi.atom() |> Zoi.nullish() |> Zoi.default(nil),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.default(nil),
              seams: Zoi.any()
            },
            coerce: true
          )

  @type t :: %__MODULE__{
          __spark_metadata__: map() | nil,
          id: atom(),
          default_family: atom() | nil,
          description: String.t() | nil,
          seams: Seams.t()
        }

  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct [__spark_metadata__: nil] ++ Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema

  @spec new(map()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_map(attrs) do
    attrs = normalize_embedded(attrs, :seams, Seams)
    Zoi.parse(@schema, attrs)
  end

  @spec new!(map()) :: t()
  def new!(attrs) when is_map(attrs) do
    case new(attrs) do
      {:ok, provider} -> provider
      {:error, reason} -> raise ArgumentError, "Invalid extension provider: #{inspect(reason)}"
    end
  end

  defp normalize_embedded(attrs, key, module) do
    case Map.get(attrs, key) do
      %{__struct__: ^module} = value -> Map.put(attrs, key, value)
      nil -> Map.put(attrs, key, module.new!(%{}))
      value when is_map(value) -> Map.put(attrs, key, module.new!(value))
      value -> Map.put(attrs, key, value)
    end
  end
end
