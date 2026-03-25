defmodule ReqLlmNext.ExecutionSurface do
  @moduledoc """
  Describes one supported execution surface for an operation family.
  """

  @derive Jason.Encoder

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.atom(),
              operation: Zoi.enum([:text, :object, :embed, :image, :transcription, :speech]),
              semantic_protocol: Zoi.atom(),
              wire_format: Zoi.atom(),
              transport: Zoi.atom(),
              features: Zoi.map() |> Zoi.default(%{}),
              fallback_ids: Zoi.array(Zoi.atom()) |> Zoi.default([])
            },
            coerce: true
          )

  @type operation :: :text | :object | :embed | :image | :transcription | :speech

  @type t :: %__MODULE__{
          id: atom(),
          operation: operation(),
          semantic_protocol: atom(),
          wire_format: atom(),
          transport: atom(),
          features: map(),
          fallback_ids: [atom()]
        }

  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema

  @spec new(map()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_map(attrs) do
    Zoi.parse(@schema, attrs)
  end

  @spec new!(map()) :: t()
  def new!(attrs) when is_map(attrs) do
    case new(attrs) do
      {:ok, surface} -> surface
      {:error, reason} -> raise ArgumentError, "Invalid execution surface: #{inspect(reason)}"
    end
  end
end
