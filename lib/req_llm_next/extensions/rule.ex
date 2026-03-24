defmodule ReqLlmNext.Extensions.Rule do
  @moduledoc """
  Narrow, opt-in override rule applied after family selection.
  """

  alias ReqLlmNext.Extensions.{Criteria, Seams}

  @derive Jason.Encoder

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.atom(),
              priority: Zoi.integer() |> Zoi.default(100),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.default(nil),
              criteria: Zoi.any(),
              patch: Zoi.any()
            },
            coerce: true
          )

  @type t :: %__MODULE__{
          id: atom(),
          priority: integer(),
          description: String.t() | nil,
          criteria: Criteria.t(),
          patch: Seams.t()
        }

  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema

  @spec new(map()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_map(attrs) do
    attrs =
      attrs
      |> normalize_embedded(:criteria, Criteria)
      |> normalize_embedded(:patch, Seams)

    Zoi.parse(@schema, attrs)
  end

  @spec new!(map()) :: t()
  def new!(attrs) when is_map(attrs) do
    case new(attrs) do
      {:ok, rule} -> rule
      {:error, reason} -> raise ArgumentError, "Invalid extension rule: #{inspect(reason)}"
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
