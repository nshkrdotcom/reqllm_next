defmodule ReqLlmNext.StreamResponse do
  @moduledoc """
  Stream response struct containing the lazy stream and model info.

  The stream can emit:
  - Strings (text content)
  - `{:thinking, text}` tuples (reasoning content from o-series models)
  - `{:tool_call_delta, map}` tuples (tool call fragments from OpenAI)
  - `{:tool_call_start, map}` tuples (tool call start from Anthropic)
  - `{:usage, map}` tuples (usage metrics)
  - `{:meta, map}` tuples (metadata like terminal?, finish_reason)
  - `nil` (stream termination)
  """

  alias ReqLlmNext.Response.Materializer

  defstruct [:stream, :model, :cancel_fn, :metadata_ref]

  @type t :: %__MODULE__{
          stream: Enumerable.t(),
          model: LLMDB.Model.t(),
          cancel_fn: (-> :ok) | nil,
          metadata_ref: reference() | nil
        }

  @doc """
  Cancel an in-progress stream.

  If the stream has a cancel function, it will be called to stop the stream.
  Returns :ok whether or not there was a cancel function.

  ## Examples

      {:ok, stream_resp} = ReqLlmNext.stream_text("openai:gpt-4o-mini", "Hello")
      ReqLlmNext.StreamResponse.cancel(stream_resp)

  """
  @spec cancel(t()) :: :ok
  def cancel(%__MODULE__{cancel_fn: nil}), do: :ok
  def cancel(%__MODULE__{cancel_fn: cancel_fn}) when is_function(cancel_fn, 0), do: cancel_fn.()

  @doc """
  Consume the stream and return the full text.

  Filters out non-text items (usage tuples, tool call deltas, etc.).
  """
  @spec text(t()) :: String.t()
  def text(%__MODULE__{stream: stream}) do
    case Materializer.collect(stream) do
      {:ok, materialized} -> Materializer.text(materialized)
      {:error, _error} -> ""
    end
  end

  @doc """
  Extract thinking/reasoning content from stream.

  Returns concatenated reasoning text from `{:thinking, text}` tuples
  emitted by reasoning models (o-series, GPT-5).
  """
  @spec thinking(t()) :: String.t()
  def thinking(%__MODULE__{stream: stream}) do
    case Materializer.collect(stream) do
      {:ok, materialized} -> Materializer.thinking(materialized)
      {:error, _error} -> ""
    end
  end

  @doc """
  Consume the stream and return usage metadata if present.
  """
  @spec usage(t()) :: map() | nil
  def usage(%__MODULE__{stream: stream}) do
    case Materializer.collect(stream) do
      {:ok, materialized} -> Materializer.usage(materialized)
      {:error, _error} -> nil
    end
  end

  @doc """
  Consume the stream and return the parsed JSON object.

  Joins all stream chunks and decodes as JSON.
  """
  @spec object(t()) :: map() | nil
  def object(%__MODULE__{} = resp) do
    case ReqLlmNext.ObjectDecoder.decode(text(resp)) do
      {:ok, object} -> object
      {:error, _} -> nil
    end
  end

  @doc """
  Consume the stream and return assembled tool calls.

  Tool calls are streamed as deltas that need to be assembled into complete
  ToolCall structs.
  """
  @spec tool_calls(t()) :: [ReqLlmNext.ToolCall.t()]
  def tool_calls(%__MODULE__{stream: stream}) do
    case Materializer.collect(stream) do
      {:ok, materialized} -> Materializer.tool_calls(materialized)
      {:error, _error} -> []
    end
  end
end
