defmodule ReqLlmNext.Wire.Streaming do
  @moduledoc """
  Behaviour for streaming wire protocols.

  Wire protocols own request encoding plus provider-family payload framing.
  Canonical response normalization belongs to semantic protocol modules.
  """

  alias ReqLlmNext.Provider

  @type sse_event :: %{data: String.t(), event: String.t() | nil, id: String.t() | nil}

  @doc """
  Returns the endpoint path for this wire protocol.
  """
  @callback endpoint() :: String.t()

  @doc """
  Encodes a prompt into a request body map.
  """
  @callback encode_body(LLMDB.Model.t(), String.t(), keyword()) :: map()

  @doc """
  Decodes one framed transport payload into provider-family events.
  """
  @callback decode_wire_event(sse_event() | %{data: map()} | %{data: binary()}) :: [term()]

  @doc """
  Returns the options schema for this wire protocol.
  """
  @callback options_schema() :: keyword()

  @doc """
  Builds a custom Finch request when the wire needs a dynamic endpoint or request shape.
  """
  @callback build_request(
              module(),
              LLMDB.Model.t(),
              String.t() | ReqLlmNext.Context.t(),
              keyword()
            ) ::
              {:ok, Finch.Request.t()} | {:error, term()}

  @doc """
  Returns wire-specific headers for the request.

  Some wire protocols need custom headers based on options (e.g., Anthropic
  beta headers for thinking/caching features).
  """
  @callback headers(keyword()) :: [{String.t(), String.t()}]

  @optional_callbacks options_schema: 0, headers: 1, build_request: 4

  @doc """
  Builds a complete Finch request using provider and wire protocol.
  """
  @spec build_request(module(), module(), LLMDB.Model.t(), String.t(), keyword()) ::
          {:ok, Finch.Request.t()} | {:error, term()}
  def build_request(provider_mod, wire_mod, model, prompt, opts) do
    if optional_callback?(wire_mod, :build_request, 4) do
      wire_mod.build_request(provider_mod, model, prompt, opts)
    else
      wire_headers = get_wire_headers(wire_mod, opts)

      with {:ok, url} <- Provider.request_url(provider_mod, model, wire_mod.endpoint(), opts),
           {:ok, headers} <-
             Provider.request_headers(
               provider_mod,
               model,
               opts,
               wire_headers ++ [{"Accept", "text/event-stream"}]
             ) do
        body =
          wire_mod.encode_body(model, prompt, opts)
          |> Jason.encode!()

        {:ok, Finch.build(:post, url, headers, body)}
      end
    end
  end

  defp get_wire_headers(wire_mod, opts) do
    if optional_callback?(wire_mod, :headers, 1) do
      wire_mod.headers(opts)
    else
      [{"Content-Type", "application/json"}]
    end
  end

  defp optional_callback?(module, function_name, arity) do
    Code.ensure_loaded?(module) and function_exported?(module, function_name, arity)
  end
end
