defmodule ReqLlmNext.SurfacePreparation.CerebrasChatTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.ExecutionSurface
  alias ReqLlmNext.SurfacePreparation.CerebrasChat

  defp surface do
    %ExecutionSurface{
      id: :openai_chat_text_http_sse,
      operation: :text,
      semantic_protocol: :openai_chat,
      wire_format: :openai_chat_sse_json,
      transport: :http_sse,
      features: %{}
    }
  end

  test "rejects unsupported frequency penalty" do
    assert {:error, error} =
             CerebrasChat.validate(surface(), frequency_penalty: 0.2)

    assert Exception.message(error) =~ "frequency_penalty is not supported"
  end

  test "rejects function-specific tool choice" do
    assert {:error, error} =
             CerebrasChat.validate(surface(), tool_choice: %{type: "tool", name: "lookup"})

    assert Exception.message(error) =~ "tool_choice only supports"
  end
end
