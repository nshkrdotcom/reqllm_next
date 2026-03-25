defmodule ReqLlmNext.SurfacePreparation.ZAIChatTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.ExecutionSurface
  alias ReqLlmNext.SurfacePreparation.ZAIChat

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

  test "lifts thinking from provider_options" do
    {:ok, opts} =
      ZAIChat.prepare(surface(), "Explain the result",
        provider_options: [thinking: %{type: "disabled"}]
      )

    assert opts[:thinking] == %{type: "disabled"}
    assert opts[:provider_options] == []
  end

  test "normalizes named tool choice to auto" do
    {:ok, opts} =
      ZAIChat.prepare(surface(), "Explain the result",
        tool_choice: %{type: "tool", name: "lookup"}
      )

    assert opts[:tool_choice] == "auto"
  end
end
