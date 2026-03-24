defmodule ReqLlmNext.OpenAI.ToolsTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.OpenAI
  alias ReqLlmNext.OpenAI.Tools

  test "builds OpenAI web search tools" do
    assert OpenAI.web_search_tool().type == "web_search"
    assert OpenAI.web_search_tool(version: :preview).type == "web_search_preview"
  end

  test "builds OpenAI file search tools" do
    tool = OpenAI.file_search_tool(vector_store_ids: ["vs_123"], max_num_results: 5)

    assert tool.type == "file_search"
    assert tool.vector_store_ids == ["vs_123"]
    assert tool.max_num_results == 5
  end

  test "builds OpenAI code interpreter tools" do
    tool = OpenAI.code_interpreter_tool(file_ids: ["file-123"])

    assert tool.type == "code_interpreter"
    assert tool.container == %{type: "auto", file_ids: ["file-123"]}
  end

  test "builds OpenAI computer use tools" do
    tool = OpenAI.computer_use_tool(display_width: 1440, display_height: 900)

    assert tool.type == "computer_use_preview"
    assert tool.display_width == 1440
    assert tool.display_height == 900
    assert tool.environment == "browser"
  end

  test "recognizes provider-native OpenAI helper maps" do
    assert Tools.provider_native_tool?(OpenAI.web_search_tool())
    refute Tools.provider_native_tool?(%{type: "function"})
  end

  test "exposes include helpers for built-in tool results" do
    assert OpenAI.web_search_sources_include() == "web_search_call.action.sources"
    assert OpenAI.file_search_results_include() == "file_search_call.results"
  end
end
