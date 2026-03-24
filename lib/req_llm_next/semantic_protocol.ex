defmodule ReqLlmNext.SemanticProtocol do
  @moduledoc """
  Behaviour for semantic protocol normalization.

  Semantic protocols translate provider-family events from a wire format into the
  canonical ReqLlmNext chunk stream consumed by the public API.
  """

  @type wire_event :: map() | :done | {:decode_error, term()}

  @callback decode_event(wire_event(), LLMDB.Model.t() | nil) :: [term()]
end
