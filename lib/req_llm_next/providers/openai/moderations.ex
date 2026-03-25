defmodule ReqLlmNext.OpenAI.Moderations do
  @moduledoc """
  OpenAI Moderations API helpers.
  """

  alias ReqLlmNext.OpenAI.Client

  @spec create(term(), keyword()) :: {:ok, term()} | {:error, term()}
  def create(input, opts \\ []) do
    Client.json_request(:post, "/v1/moderations", build_body(input, opts), opts)
  end

  @doc false
  @spec build_body(term(), keyword()) :: map()
  def build_body(input, opts \\ []) do
    %{
      input: normalize_input(input)
    }
    |> maybe_put(:model, Keyword.get(opts, :model, "omni-moderation-latest"))
  end

  defp normalize_input(%ReqLlmNext.Context{} = context),
    do: Jason.decode!(Jason.encode!(context.messages))

  defp normalize_input(%ReqLlmNext.Context.Message{} = message),
    do: Jason.decode!(Jason.encode!([message]))

  defp normalize_input(input), do: input

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
