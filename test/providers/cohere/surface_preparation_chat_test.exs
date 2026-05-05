defmodule ReqLlmNext.SurfacePreparation.CohereChatTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Error
  alias ReqLlmNext.ExecutionSurface
  alias ReqLlmNext.ModelProfile.SurfaceCatalog.Helpers
  alias ReqLlmNext.SurfacePreparation.CohereChat
  alias ReqLlmNext.Tool

  defp surface(operation) do
    ExecutionSurface.new!(%{
      id: Helpers.surface_id(:cohere_chat, operation, :http_sse),
      operation: operation,
      semantic_protocol: :cohere_chat,
      wire_format: :cohere_chat_sse_json,
      transport: :http_sse,
      features: %{streaming: true},
      fallback_ids: []
    })
  end

  test "rejects tools on Cohere chat surfaces" do
    tool =
      Tool.new!(
        name: "lookup_weather",
        description: "Get weather",
        parameter_schema: [location: [type: :string, required: true]],
        callback: fn _args -> {:ok, %{}} end
      )

    assert {:error, %Error.Invalid.Parameter{}} =
             CohereChat.validate(surface(:text), tools: [tool])
  end

  test "rejects native object schema when Cohere documents are present" do
    assert {:error, %Error.Invalid.Parameter{}} =
             CohereChat.validate(
               surface(:object),
               operation: :object,
               provider_options: [documents: ["doc one"]]
             )
  end
end
