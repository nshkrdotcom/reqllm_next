defmodule ReqLlmNext.Realtime.Command do
  @moduledoc """
  Canonical realtime command contract.
  """

  @schema Zoi.struct(
            __MODULE__,
            %{
              type:
                Zoi.enum([
                  :session_update,
                  :conversation_item_create,
                  :input_audio_append,
                  :input_audio_commit,
                  :response_create,
                  :response_cancel
                ]),
              data: Zoi.any() |> Zoi.nullish() |> Zoi.default(nil),
              metadata: Zoi.map() |> Zoi.default(%{})
            },
            coerce: true
          )

  @type t :: %__MODULE__{
          type:
            :session_update
            | :conversation_item_create
            | :input_audio_append
            | :input_audio_commit
            | :response_create
            | :response_cancel,
          data: term(),
          metadata: map()
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
      {:ok, command} -> command
      {:error, reason} -> raise ArgumentError, "Invalid realtime command: #{inspect(reason)}"
    end
  end

  @spec session_update(keyword() | map()) :: t()
  def session_update(opts \\ %{}) do
    new!(%{type: :session_update, data: normalize_map(opts)})
  end

  @spec conversation_item_create(map()) :: t()
  def conversation_item_create(item) when is_map(item) do
    new!(%{type: :conversation_item_create, data: item})
  end

  @spec input_audio_append(binary(), map()) :: t()
  def input_audio_append(audio, metadata \\ %{}) when is_binary(audio) and is_map(metadata) do
    new!(%{type: :input_audio_append, data: audio, metadata: metadata})
  end

  @spec input_audio_commit() :: t()
  def input_audio_commit do
    new!(%{type: :input_audio_commit})
  end

  @spec response_create(keyword() | map()) :: t()
  def response_create(opts \\ %{}) do
    new!(%{type: :response_create, data: normalize_map(opts)})
  end

  @spec response_cancel() :: t()
  def response_cancel do
    new!(%{type: :response_cancel})
  end

  defp normalize_map(opts) when is_list(opts), do: Enum.into(opts, %{})
  defp normalize_map(opts) when is_map(opts), do: opts
  defp normalize_map(_opts), do: %{}
end
