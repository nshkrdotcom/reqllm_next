defmodule ReqLlmNext.Response.OutputItem do
  @moduledoc """
  Canonical response output item for normalized provider outputs.
  """

  alias ReqLlmNext.Context.ContentPart

  @derive Jason.Encoder

  @schema Zoi.struct(
            __MODULE__,
            %{
              type:
                Zoi.enum([
                  :text,
                  :thinking,
                  :content_part,
                  :tool_call,
                  :audio,
                  :transcript,
                  :provider_item,
                  :annotation,
                  :refusal
                ]),
              data: Zoi.any() |> Zoi.nullish() |> Zoi.default(nil),
              metadata: Zoi.map() |> Zoi.default(%{})
            },
            coerce: true
          )

  @type t :: %__MODULE__{
          type:
            :text
            | :thinking
            | :content_part
            | :tool_call
            | :audio
            | :transcript
            | :provider_item
            | :annotation
            | :refusal,
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
      {:ok, item} -> item
      {:error, reason} -> raise ArgumentError, "Invalid output item: #{inspect(reason)}"
    end
  end

  @spec text(String.t(), map()) :: t()
  def text(text, metadata \\ %{}) when is_binary(text) and is_map(metadata) do
    new!(%{type: :text, data: text, metadata: metadata})
  end

  @spec thinking(String.t(), map()) :: t()
  def thinking(text, metadata \\ %{}) when is_binary(text) and is_map(metadata) do
    new!(%{type: :thinking, data: text, metadata: metadata})
  end

  @spec content_part(ContentPart.t()) :: t()
  def content_part(%ContentPart{} = part) do
    new!(%{type: :content_part, data: part, metadata: part.metadata || %{}})
  end

  @spec tool_call(ReqLlmNext.ToolCall.t()) :: t()
  def tool_call(tool_call) do
    new!(%{type: :tool_call, data: tool_call})
  end

  @spec audio(binary(), map()) :: t()
  def audio(data, metadata \\ %{}) when is_binary(data) and is_map(metadata) do
    new!(%{type: :audio, data: data, metadata: metadata})
  end

  @spec transcript(String.t(), map()) :: t()
  def transcript(text, metadata \\ %{}) when is_binary(text) and is_map(metadata) do
    new!(%{type: :transcript, data: text, metadata: metadata})
  end

  @spec provider_item(map()) :: t()
  def provider_item(item) when is_map(item) do
    new!(%{type: :provider_item, data: item})
  end

  @spec annotation(term(), map()) :: t()
  def annotation(data, metadata \\ %{}) when is_map(metadata) do
    new!(%{type: :annotation, data: data, metadata: metadata})
  end

  @spec refusal(String.t(), map()) :: t()
  def refusal(text, metadata \\ %{}) when is_binary(text) and is_map(metadata) do
    new!(%{type: :refusal, data: text, metadata: metadata})
  end

  @spec from_content_part(ContentPart.t()) :: t()
  def from_content_part(%ContentPart{type: :text, text: text, metadata: metadata}) do
    text(text || "", metadata || %{})
  end

  def from_content_part(%ContentPart{type: :thinking, text: text, metadata: metadata}) do
    thinking(text || "", metadata || %{})
  end

  def from_content_part(%ContentPart{} = part) do
    content_part(part)
  end
end
