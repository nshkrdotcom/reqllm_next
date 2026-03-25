defmodule ReqLlmNext.Speech.Result do
  @moduledoc """
  Canonical result contract for speech generation operations.
  """

  @derive Jason.Encoder

  @schema Zoi.struct(
            __MODULE__,
            %{
              audio: Zoi.any(typespec: quote(do: binary())),
              media_type: Zoi.string(),
              format: Zoi.string(),
              provider_meta: Zoi.map() |> Zoi.default(%{})
            },
            coerce: true
          )

  @type t :: %__MODULE__{
          audio: binary(),
          media_type: String.t(),
          format: String.t(),
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
      {:error, reason} -> raise ArgumentError, "Invalid speech result: #{inspect(reason)}"
    end
  end
end
