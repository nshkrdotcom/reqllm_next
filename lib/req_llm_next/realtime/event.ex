defmodule ReqLlmNext.Realtime.Event do
  @moduledoc """
  Canonical realtime event contract.
  """

  @schema Zoi.struct(
            __MODULE__,
            %{
              type:
                Zoi.enum([
                  :text_delta,
                  :thinking_delta,
                  :audio_delta,
                  :transcript_delta,
                  :tool_call_start,
                  :tool_call_delta,
                  :usage,
                  :meta,
                  :error,
                  :provider_event
                ]),
              data: Zoi.any() |> Zoi.nullish() |> Zoi.default(nil),
              metadata: Zoi.map() |> Zoi.default(%{})
            },
            coerce: true
          )

  @type t :: %__MODULE__{
          type:
            :text_delta
            | :thinking_delta
            | :audio_delta
            | :transcript_delta
            | :tool_call_start
            | :tool_call_delta
            | :usage
            | :meta
            | :error
            | :provider_event,
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
      {:ok, event} -> event
      {:error, reason} -> raise ArgumentError, "Invalid realtime event: #{inspect(reason)}"
    end
  end

  @spec text_delta(String.t(), map()) :: t()
  def text_delta(text, metadata \\ %{}) when is_binary(text) and is_map(metadata) do
    new!(%{type: :text_delta, data: text, metadata: metadata})
  end

  @spec thinking_delta(String.t(), map()) :: t()
  def thinking_delta(text, metadata \\ %{}) when is_binary(text) and is_map(metadata) do
    new!(%{type: :thinking_delta, data: text, metadata: metadata})
  end

  @spec audio_delta(binary(), map()) :: t()
  def audio_delta(data, metadata \\ %{}) when is_binary(data) and is_map(metadata) do
    new!(%{type: :audio_delta, data: data, metadata: metadata})
  end

  @spec transcript_delta(String.t(), map()) :: t()
  def transcript_delta(text, metadata \\ %{}) when is_binary(text) and is_map(metadata) do
    new!(%{type: :transcript_delta, data: text, metadata: metadata})
  end

  @spec tool_call_start(map(), map()) :: t()
  def tool_call_start(data, metadata \\ %{}) when is_map(data) and is_map(metadata) do
    new!(%{type: :tool_call_start, data: data, metadata: metadata})
  end

  @spec tool_call_delta(map(), map()) :: t()
  def tool_call_delta(data, metadata \\ %{}) when is_map(data) and is_map(metadata) do
    new!(%{type: :tool_call_delta, data: data, metadata: metadata})
  end

  @spec usage(map()) :: t()
  def usage(data) when is_map(data) do
    new!(%{type: :usage, data: data})
  end

  @spec meta(map()) :: t()
  def meta(data) when is_map(data) do
    new!(%{type: :meta, data: data})
  end

  @spec error(map()) :: t()
  def error(data) when is_map(data) do
    new!(%{type: :error, data: data})
  end

  @spec provider_event(map()) :: t()
  def provider_event(data) when is_map(data) do
    new!(%{type: :provider_event, data: data})
  end
end
