defmodule ReqLlmNext.Anthropic.ToolsTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Anthropic

  test "builds provider-native server tools" do
    assert Anthropic.web_search_tool(max_uses: 3).type == "web_search_20250305"
    assert Anthropic.code_execution_tool().type == "code_execution_20250825"
    assert Anthropic.computer_use_tool(display_width_px: 1280).display_width_px == 1280
    assert Anthropic.bash_tool().type == "bash_20250124"
    assert Anthropic.text_editor_tool().type == "text_editor_20250124"
  end

  test "builds MCP server definitions" do
    server =
      Anthropic.mcp_server(
        "https://mcp.example.com",
        name: "remote_tools",
        authorization_token: "secret"
      )

    assert server.type == "url"
    assert server.url == "https://mcp.example.com"
    assert server.name == "remote_tools"
    assert server.authorization_token == "secret"
  end
end
