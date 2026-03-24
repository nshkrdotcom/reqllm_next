defmodule ReqLlmNext.Coverage.OpenAI.WebSocketCoverageTest do
  @moduledoc """
  Curated OpenAI Responses WebSocket coverage tests.

  Uses replay fixtures by default and can be re-recorded against live APIs when
  the websocket lane changes.
  """

  use ReqLlmNext.ProviderTest.Comprehensive, provider: :openai, group: :websocket
end
