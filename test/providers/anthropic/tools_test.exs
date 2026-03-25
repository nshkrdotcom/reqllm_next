defmodule ReqLlmNext.Anthropic.ToolsTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Anthropic

  test "builds provider-native server tools" do
    assert Anthropic.web_search_tool(max_uses: 3).type == "web_search_20250305"
    assert Anthropic.web_search_tool(dynamic_filtering: true).type == "web_search_20260209"
    assert Anthropic.web_fetch_tool(max_uses: 2).type == "web_fetch_20250910"
    assert Anthropic.web_fetch_tool(dynamic_filtering: true).type == "web_fetch_20260209"
    assert Anthropic.code_execution_tool().type == "code_execution_20250825"
    assert Anthropic.computer_use_tool(display_width_px: 1280).display_width_px == 1280

    assert Anthropic.computer_use_tool(version: :latest, enable_zoom: true).type ==
             "computer_20251124"

    assert Anthropic.bash_tool().type == "bash_20250124"
    assert Anthropic.text_editor_tool().type == "text_editor_20250728"
    assert Anthropic.text_editor_tool().name == "str_replace_based_edit_tool"
  end

  test "builds web fetch tools with documented options" do
    tool =
      Anthropic.web_fetch_tool(
        allowed_callers: ["direct"],
        allowed_domains: ["docs.anthropic.com"],
        citations: %{enabled: true},
        max_content_tokens: 50_000
      )

    assert tool.allowed_callers == ["direct"]
    assert tool.allowed_domains == ["docs.anthropic.com"]
    assert tool.citations == %{enabled: true}
    assert tool.max_content_tokens == 50_000
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
