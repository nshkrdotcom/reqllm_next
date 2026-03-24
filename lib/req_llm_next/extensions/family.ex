defmodule ReqLlmNext.Extensions.Family do
  @moduledoc """
  Default execution-family declaration consumed by the extension manifest.
  """

  alias ReqLlmNext.Extensions.{Criteria, Seams}

  @derive Jason.Encoder

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.atom(),
              extends: Zoi.atom() |> Zoi.nullish() |> Zoi.default(nil),
              priority: Zoi.integer() |> Zoi.default(100),
              default?: Zoi.boolean() |> Zoi.default(false),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.default(nil),
              criteria: Zoi.any(),
              seams: Zoi.any()
            },
            coerce: true
          )

  @type t :: %__MODULE__{
          __spark_metadata__: map() | nil,
          id: atom(),
          extends: atom() | nil,
          priority: integer(),
          default?: boolean(),
          description: String.t() | nil,
          criteria: Criteria.t(),
          seams: Seams.t()
        }

  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct [__spark_metadata__: nil] ++ Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema

  @spec new(map()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_map(attrs) do
    attrs =
      attrs
      |> normalize_embedded(:criteria, Criteria)
      |> normalize_embedded(:seams, Seams)

    Zoi.parse(@schema, attrs)
  end

  @spec new!(map()) :: t()
  def new!(attrs) when is_map(attrs) do
    case new(attrs) do
      {:ok, family} -> family
      {:error, reason} -> raise ArgumentError, "Invalid extension family: #{inspect(reason)}"
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
