defmodule ReqLlmNext.Response.Materializer do
  @moduledoc false

  alias ReqLlmNext.Context
  alias ReqLlmNext.Context.{ContentPart, Message}
  alias ReqLlmNext.Response
  alias ReqLlmNext.Response.OutputItem

  @schema Zoi.struct(
            __MODULE__,
            %{
              output_items: Zoi.array(Zoi.any()) |> Zoi.default([]),
              tool_acc: Zoi.map() |> Zoi.default(%{}),
              usage: Zoi.map() |> Zoi.nullish() |> Zoi.default(nil),
              meta: Zoi.map() |> Zoi.default(%{})
            },
            coerce: true
          )

  @type t :: %__MODULE__{
          output_items: [OutputItem.t()],
          tool_acc: map(),
          usage: map() | nil,
          meta: map()
        }

  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema

  @spec new(map()) :: {:ok, t()} | {:error, term()}
  def new(attrs \\ %{}) when is_map(attrs) do
    Zoi.parse(@schema, attrs)
  end

  @spec new!(map()) :: t()
  def new!(attrs \\ %{}) when is_map(attrs) do
    case new(attrs) do
      {:ok, materialized} -> materialized
      {:error, reason} -> raise ArgumentError, "Invalid materializer state: #{inspect(reason)}"
    end
  end

  @spec collect(Enumerable.t()) :: {:ok, t()} | {:error, term()}
  def collect(stream) do
    stream
    |> Enum.reduce_while({:ok, empty()}, &consume_chunk/2)
    |> case do
      {:ok, %__MODULE__{} = materialized} ->
        {:ok, finalize(materialized)}

      {:error, _} = error ->
        error
    end
  end

  @spec text(t()) :: String.t()
  def text(%__MODULE__{output_items: output_items}) do
    output_items
    |> Enum.flat_map(fn
      %OutputItem{type: :text, data: text} when is_binary(text) -> [text]
      _ -> []
    end)
    |> Enum.join("")
  end

  @spec thinking(t()) :: String.t()
  def thinking(%__MODULE__{output_items: output_items}) do
    output_items
    |> Enum.flat_map(fn
      %OutputItem{type: :thinking, data: text} when is_binary(text) -> [text]
      _ -> []
    end)
    |> Enum.join("")
  end

  @spec tool_calls(t()) :: [ReqLlmNext.ToolCall.t()]
  def tool_calls(%__MODULE__{tool_acc: tool_acc}) do
    tool_acc
    |> Map.values()
    |> Enum.sort_by(& &1.index)
    |> Enum.map(&finalize_tool_call/1)
  end

  @spec usage(t()) :: map() | nil
  def usage(%__MODULE__{usage: usage}), do: usage

  @spec finish_reason(t()) :: atom() | nil
  def finish_reason(%__MODULE__{meta: meta}), do: meta[:finish_reason]

  @spec provider_meta(t()) :: map()
  def provider_meta(%__MODULE__{meta: meta, output_items: output_items}) when is_map(meta) do
    provider_meta =
      meta
      |> Map.drop([:terminal?, :finish_reason])
      |> Enum.into(%{})

    provider_items = provider_items(output_items)

    if provider_items == [] do
      provider_meta
    else
      Map.put(provider_meta, :provider_items, provider_items)
    end
  end

  @spec assistant_message(t()) :: Message.t() | nil
  def assistant_message(%__MODULE__{} = materialized) do
    content_parts = content_parts(materialized.output_items)
    tool_calls = tool_calls(materialized)

    if content_parts != [] or tool_calls != [] do
      %Message{
        role: :assistant,
        content: content_parts,
        tool_calls: if(tool_calls == [], do: nil, else: tool_calls)
      }
    else
      nil
    end
  end

  @spec response(Response.t(), t()) :: Response.t()
  def response(%Response{} = response, %__MODULE__{} = materialized) do
    message = assistant_message(materialized)

    updated_context =
      if message do
        Context.append(response.context, message)
      else
        response.context
      end

    %{
      response
      | stream?: false,
        stream: nil,
        message: message,
        context: updated_context,
        output_items: materialized.output_items,
        usage: usage(materialized) || response.usage,
        finish_reason: finish_reason(materialized) || response.finish_reason,
        provider_meta: Map.merge(response.provider_meta || %{}, provider_meta(materialized))
    }
  end

  defp empty do
    new!(%{})
  end

  defp finalize(%__MODULE__{} = materialized) do
    %{materialized | output_items: materialized_output_items(materialized)}
  end

  defp consume_chunk({:error, error_info}, {:ok, _materialized}) do
    error =
      ReqLlmNext.Error.API.Stream.exception(
        reason: error_info.message,
        cause: error_info
      )

    {:halt, {:error, error}}
  end

  defp consume_chunk(text, {:ok, %__MODULE__{} = materialized}) when is_binary(text) do
    {:cont, {:ok, add_output_item(materialized, OutputItem.text(text))}}
  end

  defp consume_chunk({:thinking, text}, {:ok, %__MODULE__{} = materialized})
       when is_binary(text) do
    {:cont, {:ok, add_output_item(materialized, OutputItem.thinking(text))}}
  end

  defp consume_chunk({:content_part, %ContentPart{} = part}, {:ok, %__MODULE__{} = materialized}) do
    {:cont, {:ok, add_output_item(materialized, OutputItem.from_content_part(part))}}
  end

  defp consume_chunk({:usage, usage_map}, {:ok, %__MODULE__{} = materialized}) do
    {:cont, {:ok, %{materialized | usage: usage_map}}}
  end

  defp consume_chunk({:audio, data}, {:ok, %__MODULE__{} = materialized}) when is_binary(data) do
    {:cont, {:ok, add_output_item(materialized, OutputItem.audio(data))}}
  end

  defp consume_chunk({:transcript, text}, {:ok, %__MODULE__{} = materialized})
       when is_binary(text) do
    {:cont, {:ok, add_output_item(materialized, OutputItem.transcript(text))}}
  end

  defp consume_chunk({:provider_item, item}, {:ok, %__MODULE__{} = materialized})
       when is_map(item) do
    {:cont, {:ok, add_output_item(materialized, OutputItem.provider_item(item))}}
  end

  defp consume_chunk({:event, event}, {:ok, %__MODULE__{} = materialized}) when is_map(event) do
    {:cont, {:ok, add_output_item(materialized, OutputItem.provider_item(event))}}
  end

  defp consume_chunk(
         {:tool_call_delta, %{index: index} = delta},
         {:ok, %__MODULE__{} = materialized}
       ) do
    tool_acc =
      Map.update(materialized.tool_acc, index, init_tool_call(delta), &merge_tool_call(&1, delta))

    {:cont, {:ok, %{materialized | tool_acc: tool_acc}}}
  end

  defp consume_chunk(
         {:tool_call_start, %{index: index} = start},
         {:ok, %__MODULE__{} = materialized}
       ) do
    tool_acc =
      Map.update(
        materialized.tool_acc,
        index,
        init_tool_call_from_start(start),
        &merge_start(&1, start)
      )

    {:cont, {:ok, %{materialized | tool_acc: tool_acc}}}
  end

  defp consume_chunk({:meta, meta_chunk}, {:ok, %__MODULE__{} = materialized})
       when is_map(meta_chunk) do
    {:cont, {:ok, %{materialized | meta: Map.merge(materialized.meta, meta_chunk)}}}
  end

  defp consume_chunk(_other, {:ok, %__MODULE__{} = materialized}) do
    {:cont, {:ok, materialized}}
  end

  defp add_output_item(%__MODULE__{} = materialized, %OutputItem{} = item) do
    %{materialized | output_items: [item | materialized.output_items]}
  end

  defp init_tool_call(%{id: id, function: function} = delta) when not is_nil(id) do
    %{
      index: delta.index,
      id: id,
      type: delta[:type] || "function",
      name: function["name"],
      arguments: function["arguments"] || ""
    }
  end

  defp init_tool_call(delta) do
    %{
      index: delta.index,
      id: nil,
      type: delta[:type],
      name: delta[:function]["name"],
      arguments: delta[:function]["arguments"] || ""
    }
  end

  defp init_tool_call_from_start(%{index: index, id: id, name: name}) do
    %{
      index: index,
      id: id,
      type: "function",
      name: name,
      arguments: ""
    }
  end

  defp merge_tool_call(acc, %{function: function}) when is_map(function) do
    %{
      acc
      | name: acc.name || function["name"],
        arguments: acc.arguments <> (function["arguments"] || "")
    }
  end

  defp merge_tool_call(acc, %{partial_json: json}) when is_binary(json) do
    %{acc | arguments: acc.arguments <> json}
  end

  defp merge_tool_call(acc, %{id: id}) when not is_nil(id) do
    %{acc | id: id}
  end

  defp merge_tool_call(acc, _delta), do: acc

  defp merge_start(acc, %{id: id, name: name}) do
    %{acc | id: id || acc.id, name: name || acc.name}
  end

  defp finalize_tool_call(%{id: id, name: name, arguments: args}) do
    ReqLlmNext.ToolCall.new(id, name, args)
  end

  defp materialized_output_items(%__MODULE__{output_items: output_items} = materialized) do
    output_items
    |> Enum.reverse()
    |> Kernel.++(Enum.map(tool_calls(materialized), &OutputItem.tool_call/1))
  end

  defp content_parts(output_items) do
    Enum.flat_map(output_items, fn
      %OutputItem{type: :text, data: text, metadata: metadata} when is_binary(text) ->
        [ContentPart.text(text, metadata)]

      %OutputItem{type: :thinking, data: text, metadata: metadata} when is_binary(text) ->
        [ContentPart.thinking(text, metadata)]

      %OutputItem{type: :content_part, data: %ContentPart{} = part} ->
        [part]

      _ ->
        []
    end)
  end

  defp provider_items(output_items) do
    Enum.flat_map(output_items, fn
      %OutputItem{type: :provider_item, data: item} when is_map(item) -> [item]
      _ -> []
    end)
  end
end
