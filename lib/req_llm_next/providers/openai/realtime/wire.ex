defmodule ReqLlmNext.OpenAI.Realtime.Wire do
  @moduledoc false

  @spec websocket_url(String.t(), LLMDB.Model.t(), keyword()) :: String.t()
  def websocket_url(base_url, %LLMDB.Model{id: model_id}, opts \\ []) do
    base =
      base_url
      |> String.replace_prefix("https://", "wss://")
      |> Kernel.<>("/v1/realtime")

    query =
      %{}
      |> put_query(:model, model_id)
      |> put_query(:voice, Keyword.get(opts, :voice))

    if query == %{}, do: base, else: base <> "?" <> URI.encode_query(query)
  end

  @spec encode_client_event(map()) :: map()
  def encode_client_event(%{"type" => _type} = event), do: event
  def encode_client_event(%{type: _type} = event), do: event

  def encode_client_event(event) when is_map(event) do
    raise ArgumentError,
          "OpenAI Realtime client events require a :type or \"type\" field, got: #{inspect(event)}"
  end

  @spec decode_wire_event(map() | binary()) :: [term()]
  def decode_wire_event(%{data: data}) when is_binary(data) do
    decode_wire_event(data)
  end

  def decode_wire_event(data) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, decoded} when is_map(decoded) -> [decoded]
      {:ok, _decoded} -> []
      {:error, decode_error} -> [{:decode_error, decode_error}]
    end
  end

  def decode_wire_event(event) when is_map(event), do: [event]
  def decode_wire_event(_event), do: []

  defp put_query(map, _key, nil), do: map
  defp put_query(map, key, value), do: Map.put(map, key, value)
end
