defmodule ReqLlmNext.Transcription.Result do
  @moduledoc """
  Canonical result contract for transcription operations.
  """

  @derive Jason.Encoder

  @schema Zoi.struct(
            __MODULE__,
            %{
              text: Zoi.string(),
              segments: Zoi.array(Zoi.map()) |> Zoi.default([]),
              language: Zoi.string() |> Zoi.nullish() |> Zoi.default(nil),
              duration_in_seconds: Zoi.any() |> Zoi.nullish() |> Zoi.default(nil),
              provider_meta: Zoi.map() |> Zoi.default(%{})
            },
            coerce: true
          )

  @type t :: %__MODULE__{
          text: String.t(),
          segments: [map()],
          language: String.t() | nil,
          duration_in_seconds: number() | nil,
          provider_meta: map()
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
      {:ok, result} -> result
      {:error, reason} -> raise ArgumentError, "Invalid transcription result: #{inspect(reason)}"
    end
  end
end
