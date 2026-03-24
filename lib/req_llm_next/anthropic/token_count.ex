defmodule ReqLlmNext.Anthropic.TokenCount do
  @moduledoc """
  Anthropic token counting helpers for prompt sizing and preflight checks.
  """

  alias ReqLlmNext.Anthropic.Client
  alias ReqLlmNext.ModelResolver
  alias ReqLlmNext.Wire.Anthropic, as: AnthropicWire

  @spec count(ReqLlmNext.model_spec(), String.t() | ReqLlmNext.Context.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def count(model_source, prompt, opts \\ []) do
    with {:ok, model} <- ModelResolver.resolve(model_source) do
      Client.json_request(:post, "/v1/messages/count_tokens", build_body(model, prompt, opts), opts)
    end
  end

  @spec build_body(LLMDB.Model.t(), String.t() | ReqLlmNext.Context.t(), keyword()) :: map()
  def build_body(%LLMDB.Model{} = model, prompt, opts \\ []) do
    model
    |> AnthropicWire.encode_body(prompt, opts)
    |> Map.delete(:stream)
  end
end
