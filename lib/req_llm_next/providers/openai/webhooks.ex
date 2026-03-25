defmodule ReqLlmNext.OpenAI.Webhooks do
  @moduledoc """
  OpenAI webhook event parsing helpers.
  """

  alias ReqLlmNext.Error

  @response_terminal_types MapSet.new([
                             "response.completed",
                             "response.cancelled",
                             "response.failed",
                             "response.incomplete"
                           ])

  @batch_terminal_types MapSet.new([
                          "batch.completed",
                          "batch.cancelled",
                          "batch.expired",
                          "batch.failed"
                        ])

  @spec parse(binary()) :: {:ok, map()} | {:error, term()}
  def parse(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} when is_map(decoded) ->
        {:ok, decoded}

      {:ok, _decoded} ->
        {:error,
         Error.API.JsonParse.exception(
           message: "OpenAI webhook payload was not a JSON object",
           raw_json: body
         )}

      {:error, reason} ->
        {:error,
         Error.API.JsonParse.exception(
           message: "Failed to parse OpenAI webhook payload: #{Exception.message(reason)}",
           raw_json: body
         )}
    end
  end

  @spec event_type(map()) :: String.t() | nil
  def event_type(event) when is_map(event) do
    event["type"] || event[:type]
  end

  @spec response_event?(map()) :: boolean()
  def response_event?(event) when is_map(event) do
    case event_type(event) do
      "response." <> _rest -> true
      _other -> false
    end
  end

  @spec batch_event?(map()) :: boolean()
  def batch_event?(event) when is_map(event) do
    case event_type(event) do
      "batch." <> _rest -> true
      _other -> false
    end
  end

  @spec terminal?(map()) :: boolean()
  def terminal?(event) when is_map(event) do
    type = event_type(event)
    MapSet.member?(@response_terminal_types, type) or MapSet.member?(@batch_terminal_types, type)
  end

  @spec resource_id(map()) :: String.t() | nil
  def resource_id(event) when is_map(event) do
    get_in(event, ["data", "id"]) || get_in(event, [:data, :id])
  end

  @spec category(map()) :: :response | :batch | :unknown
  def category(event) when is_map(event) do
    cond do
      response_event?(event) -> :response
      batch_event?(event) -> :batch
      true -> :unknown
    end
  end
end
