defmodule ReqLlmNext.Realtime.Adapter do
  @moduledoc """
  Behaviour for provider-owned realtime adapters.
  """

  alias ReqLlmNext.Realtime.{Command, Event}

  @callback encode_command(LLMDB.Model.t(), Command.t(), keyword()) :: map()
  @callback decode_event(map() | binary(), LLMDB.Model.t(), keyword()) :: [Event.t()]
  @callback websocket_url(LLMDB.Model.t(), keyword()) :: String.t()
  @callback stream_commands(LLMDB.Model.t(), [Command.t()], keyword()) ::
              {:ok, Enumerable.t()} | {:error, term()}

  @optional_callbacks websocket_url: 2, stream_commands: 3
end
