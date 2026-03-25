defmodule ReqLlmNext.Response do
  @moduledoc """
  High-level representation of an LLM turn.

  Always contains a Context (full conversation history including the newly-generated 
  assistant/tool messages) plus rich metadata and, when streaming, a lazy `Stream` 
  of chunks.

  This struct eliminates the need for manual message extraction and context building
  in multi-turn conversations and tool calling workflows.

  ## Examples

      {:ok, response} = ReqLlmNext.generate_text("anthropic:claude-3-sonnet", context)
      ReqLlmNext.Response.text(response)  #=> "Hello! I'm Claude."
      ReqLlmNext.Response.usage(response)  #=> %{input_tokens: 12, output_tokens: 4}

      # Multi-turn conversation (no manual context building)
      {:ok, response2} = ReqLlmNext.generate_text("anthropic:claude-3-sonnet", response.context)

  """

  alias ReqLlmNext.Context
  alias ReqLlmNext.Context.{ContentPart, Message}
  alias ReqLlmNext.Response.Materializer
  alias ReqLlmNext.Response.OutputItem

  @derive {Jason.Encoder, except: [:stream]}

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.string(),
              model: Zoi.any(),
              context: Zoi.any(),
              message: Zoi.any() |> Zoi.nullish(),
              output_items: Zoi.array(Zoi.any()) |> Zoi.default([]),
              object: Zoi.map() |> Zoi.nullish() |> Zoi.default(nil),
              stream?: Zoi.boolean() |> Zoi.default(false),
              stream: Zoi.any() |> Zoi.nullish() |> Zoi.default(nil),
              usage: Zoi.map() |> Zoi.nullish(),
              finish_reason:
                Zoi.enum([:stop, :length, :tool_calls, :content_filter, :error]) |> Zoi.nullish(),
              provider_meta: Zoi.map() |> Zoi.default(%{}),
              error: Zoi.any() |> Zoi.nullish() |> Zoi.default(nil)
            },
            coerce: true
          )

  @type t :: %__MODULE__{
          id: String.t(),
          model: LLMDB.Model.t(),
          context: Context.t(),
          message: Message.t() | nil,
          output_items: [OutputItem.t()],
          object: map() | nil,
          stream?: boolean(),
          stream: Enumerable.t() | nil,
          usage: map() | nil,
          finish_reason: :stop | :length | :tool_calls | :content_filter | :error | nil,
          provider_meta: map(),
          error: Exception.t() | nil
        }

  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @doc "Returns the Zoi schema for Response"
  def schema, do: @schema

  @spec new(map()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_map(attrs) do
    attrs
    |> normalize_output_items()
    |> then(&Zoi.parse(@schema, &1))
  end

  @spec new!(map()) :: t()
  def new!(attrs) when is_map(attrs) do
    case new(attrs) do
      {:ok, response} -> response
      {:error, reason} -> raise ArgumentError, "Invalid response: #{inspect(reason)}"
    end
  end

  @doc """
  Extract text content from the response message.

  Returns the concatenated text from all content parts in the assistant message.
  Returns nil when no message is present.

  ## Examples

      iex> ReqLlmNext.Response.text(response)
      "Hello! I'm Claude and I can help you with questions."

  """
  @spec text(t()) :: String.t() | nil
  def text(%__MODULE__{output_items: output_items}) when output_items != [] do
    output_items
    |> Enum.flat_map(fn
      %OutputItem{type: :text, data: text} when is_binary(text) -> [text]
      _ -> []
    end)
    |> Enum.join("")
  end

  def text(%__MODULE__{message: nil}), do: nil

  def text(%__MODULE__{message: %Message{content: content}}) do
    content
    |> Enum.filter(&(&1.type == :text))
    |> Enum.map_join("", & &1.text)
  end

  @doc """
  Extract image content parts from the response message.
  """
  @spec images(t()) :: [ContentPart.t()]
  def images(%__MODULE__{output_items: output_items}) when output_items != [] do
    output_items
    |> Enum.flat_map(fn
      %OutputItem{type: :content_part, data: %ContentPart{} = part}
      when part.type in [:image, :image_url] ->
        [part]

      _ ->
        []
    end)
  end

  def images(%__MODULE__{message: nil}), do: []

  def images(%__MODULE__{message: %Message{content: content}}) do
    Enum.filter(content, &(&1.type in [:image, :image_url]))
  end

  @doc """
  Returns the first image content part from the response, if present.
  """
  @spec image(t()) :: ContentPart.t() | nil
  def image(%__MODULE__{} = response) do
    response
    |> images()
    |> List.first()
  end

  @doc """
  Returns the first generated binary image payload, if present.
  """
  @spec image_data(t()) :: binary() | nil
  def image_data(%__MODULE__{} = response) do
    case Enum.find(images(response), &(&1.type == :image)) do
      nil -> nil
      part -> part.data
    end
  end

  @doc """
  Returns the first generated image URL, if present.
  """
  @spec image_url(t()) :: String.t() | nil
  def image_url(%__MODULE__{} = response) do
    case Enum.find(images(response), &(&1.type == :image_url)) do
      nil -> nil
      part -> part.url
    end
  end

  @doc """
  Extract thinking/reasoning content from the response message.

  Returns the concatenated thinking content if the message contains thinking parts,
  empty string otherwise.

  ## Examples

      iex> ReqLlmNext.Response.thinking(response)
      "The user is asking about the weather..."

  """
  @spec thinking(t()) :: String.t() | nil
  def thinking(%__MODULE__{output_items: output_items}) when output_items != [] do
    output_items
    |> Enum.flat_map(fn
      %OutputItem{type: :thinking, data: text} when is_binary(text) -> [text]
      _ -> []
    end)
    |> Enum.join("")
  end

  def thinking(%__MODULE__{message: nil}), do: nil

  def thinking(%__MODULE__{message: %Message{content: content}}) do
    content
    |> Enum.filter(&(&1.type == :thinking))
    |> Enum.map_join("", & &1.text)
  end

  @doc """
  Return canonical output items grouped by explicit result channel.
  """
  @spec channels(t()) :: %{optional(OutputItem.channel()) => [OutputItem.t()]}
  def channels(%__MODULE__{output_items: output_items}) do
    Enum.into(OutputItem.channels(), %{}, fn channel ->
      {channel, Enum.filter(output_items, &(OutputItem.channel(&1) == channel))}
    end)
  end

  @doc """
  Return canonical output items for one result channel.
  """
  @spec channel_items(t(), OutputItem.channel()) :: [OutputItem.t()]
  def channel_items(%__MODULE__{output_items: output_items}, channel) when is_atom(channel) do
    Enum.filter(output_items, &(OutputItem.channel(&1) == channel))
  end

  @doc """
  Extract tool calls from the response message.

  Returns a list of tool calls if the message contains them, empty list otherwise.

  ## Examples

      iex> ReqLlmNext.Response.tool_calls(response)
      [%ToolCall{id: "call_1", function: %{name: "get_weather", arguments: "..."}}]

  """
  @spec tool_calls(t()) :: [ReqLlmNext.ToolCall.t()]
  def tool_calls(%__MODULE__{output_items: output_items}) when output_items != [] do
    Enum.flat_map(output_items, fn
      %OutputItem{type: :tool_call, data: tool_call} -> [tool_call]
      _ -> []
    end)
  end

  def tool_calls(%__MODULE__{message: nil}), do: []

  def tool_calls(%__MODULE__{message: %Message{tool_calls: tool_calls}})
      when is_list(tool_calls) do
    tool_calls
  end

  def tool_calls(%__MODULE__{message: %Message{tool_calls: nil}}), do: []

  @doc """
  Extract transcript fragments from the response output channels.
  """
  @spec transcripts(t()) :: [String.t()]
  def transcripts(%__MODULE__{} = response) do
    response
    |> channel_items(:media)
    |> Enum.flat_map(fn
      %OutputItem{type: :transcript, data: text} when is_binary(text) -> [text]
      _ -> []
    end)
  end

  @doc """
  Extract generated or streamed audio chunks from the response output channels.
  """
  @spec audio_chunks(t()) :: [binary()]
  def audio_chunks(%__MODULE__{} = response) do
    response
    |> channel_items(:media)
    |> Enum.flat_map(fn
      %OutputItem{type: :audio, data: data} when is_binary(data) -> [data]
      _ -> []
    end)
  end

  @doc """
  Extract refusal items from the response output channels.
  """
  @spec refusals(t()) :: [String.t()]
  def refusals(%__MODULE__{} = response) do
    response
    |> channel_items(:refusals)
    |> Enum.flat_map(fn
      %OutputItem{data: text} when is_binary(text) -> [text]
      _ -> []
    end)
  end

  @doc """
  Extract annotation payloads from the response output channels.
  """
  @spec annotations(t()) :: [term()]
  def annotations(%__MODULE__{} = response) do
    response
    |> channel_items(:annotations)
    |> Enum.map(& &1.data)
  end

  @doc """
  Extract provider-native item payloads from the response output channels.
  """
  @spec provider_items(t()) :: [map()]
  def provider_items(%__MODULE__{} = response) do
    response
    |> channel_items(:provider)
    |> Enum.flat_map(fn
      %OutputItem{data: item} when is_map(item) -> [item]
      _ -> []
    end)
  end

  @doc """
  Get usage statistics for this response.

  ## Examples

      iex> ReqLlmNext.Response.usage(response)
      %{input_tokens: 12, output_tokens: 8, total_tokens: 20}

  """
  @spec usage(t()) :: map() | nil
  def usage(%__MODULE__{usage: usage}), do: usage

  @doc """
  Get reasoning token count from the response usage.

  Returns the number of reasoning tokens used by reasoning models (o1, o3, etc.)
  during their internal thinking process. Returns 0 if no reasoning tokens were used.

  ## Examples

      iex> ReqLlmNext.Response.reasoning_tokens(response)
      64

  """
  @spec reasoning_tokens(t()) :: integer()
  def reasoning_tokens(%__MODULE__{usage: %{reasoning_tokens: tokens}}) when is_integer(tokens),
    do: tokens

  def reasoning_tokens(%__MODULE__{usage: usage}) when is_map(usage) do
    usage[:reasoning_tokens] || usage["reasoning_tokens"] || usage[:reasoning] ||
      usage["reasoning"] || get_in(usage, [:completion_tokens_details, :reasoning_tokens]) ||
      get_in(usage, ["completion_tokens_details", "reasoning_tokens"]) || 0
  end

  def reasoning_tokens(%__MODULE__{}), do: 0

  @doc """
  Check if the response completed successfully without errors.

  ## Examples

      iex> ReqLlmNext.Response.ok?(response)
      true

  """
  @spec ok?(t()) :: boolean()
  def ok?(%__MODULE__{error: nil}), do: true
  def ok?(%__MODULE__{error: _error}), do: false

  @doc """
  Create a stream of text content chunks from a streaming response.

  Only yields content from text chunks, filtering out metadata and other chunk types.

  ## Examples

      response
      |> ReqLlmNext.Response.text_stream()
      |> Stream.each(&IO.write/1)
      |> Stream.run()

  """
  @spec text_stream(t()) :: Enumerable.t()
  def text_stream(%__MODULE__{stream?: false}), do: []
  def text_stream(%__MODULE__{stream: nil}), do: []

  def text_stream(%__MODULE__{stream: stream}) do
    Stream.flat_map(stream, fn
      text when is_binary(text) -> [text]
      {:content_part, %ContentPart{type: :text, text: text}} when is_binary(text) -> [text]
      _ -> []
    end)
  end

  @doc """
  Create a stream of structured objects from a streaming response.

  Only yields valid objects from tool call stream chunks.

  ## Examples

      response
      |> ReqLlmNext.Response.object_stream()
      |> Stream.each(&IO.inspect/1)
      |> Stream.run()

  """
  @spec object_stream(t()) :: Enumerable.t()
  def object_stream(%__MODULE__{stream?: false}), do: []
  def object_stream(%__MODULE__{stream: nil}), do: []

  def object_stream(%__MODULE__{stream: stream}) do
    stream
    |> Stream.filter(fn
      {:tool_call_delta, _} -> true
      {:tool_call_start, _} -> true
      _ -> false
    end)
  end

  @doc """
  Materialize a streaming response into a complete response.

  Consumes the entire stream, builds the complete message, and returns
  a new response with the stream consumed and message populated.

  ## Examples

      {:ok, complete_response} = ReqLlmNext.Response.join_stream(streaming_response)

  """
  @spec join_stream(t()) :: {:ok, t()} | {:error, term()}
  def join_stream(%__MODULE__{stream?: false} = response), do: {:ok, response}
  def join_stream(%__MODULE__{stream: nil} = response), do: {:ok, response}

  def join_stream(%__MODULE__{stream: stream} = response) do
    case Materializer.collect(stream) do
      {:error, error} ->
        {:error, error}

      {:ok, materialized} ->
        {:ok, Materializer.response(response, materialized)}
    end
  rescue
    e -> {:error, e}
  end

  @doc """
  Get the object from the response.
  """
  @spec object(t()) :: map() | nil
  def object(%__MODULE__{object: object}), do: object

  @doc """
  Return canonical normalized output items for this response.
  """
  @spec output_items(t()) :: [OutputItem.t()]
  def output_items(%__MODULE__{output_items: output_items}), do: output_items

  @doc """
  Get the finish reason for this response.
  """
  @spec finish_reason(t()) :: :stop | :length | :tool_calls | :content_filter | :error | nil
  def finish_reason(%__MODULE__{finish_reason: reason}), do: reason

  @doc """
  Build a response with context evolution.

  The context in the response includes all original messages plus the new assistant message.
  This is the preferred way to construct responses in the Executor.

  ## Parameters

    * `model` - The LLMDB.Model struct
    * `original_context` - The input context before the response
    * `message` - The assistant message from the response
    * `opts` - Optional fields: :id, :object, :usage, :finish_reason, :provider_meta

  ## Examples

      response = Response.build(model, context, message, usage: %{input_tokens: 10})

  """
  @spec build(LLMDB.Model.t(), Context.t(), Message.t() | nil, keyword()) :: t()
  def build(model, original_context, message, opts \\ []) do
    evolved_context =
      if message do
        Context.append(original_context, message)
      else
        original_context
      end

    %__MODULE__{
      id: opts[:id] || generate_id(),
      model: model,
      context: evolved_context,
      message: message,
      output_items: opts[:output_items] || message_output_items(message),
      object: opts[:object],
      usage: opts[:usage],
      finish_reason: opts[:finish_reason],
      provider_meta: opts[:provider_meta] || %{}
    }
  end

  defp generate_id do
    "resp_" <> (:crypto.strong_rand_bytes(12) |> Base.url_encode64(padding: false))
  end

  defp normalize_output_items(%{output_items: output_items} = attrs) when is_list(output_items),
    do: attrs

  defp normalize_output_items(%{message: %Message{} = message} = attrs) do
    Map.put(attrs, :output_items, message_output_items(message))
  end

  defp normalize_output_items(attrs), do: Map.put(attrs, :output_items, [])

  defp message_output_items(nil), do: []

  defp message_output_items(%Message{} = message) do
    content_items =
      Enum.map(message.content || [], &OutputItem.from_content_part/1)

    tool_items =
      Enum.map(message.tool_calls || [], &OutputItem.tool_call/1)

    content_items ++ tool_items
  end
end
