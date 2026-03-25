defmodule ReqLlmNext.Wire.AnthropicTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Context
  alias ReqLlmNext.TestModels
  alias ReqLlmNext.Tool
  alias ReqLlmNext.ToolCall
  alias ReqLlmNext.Wire.Anthropic

  describe "endpoint/0" do
    test "returns messages endpoint" do
      assert Anthropic.endpoint() == "/v1/messages"
    end
  end

  describe "headers/1" do
    test "returns base headers with version and content-type" do
      headers = Anthropic.headers([])

      assert {"anthropic-version", "2023-06-01"} in headers
      assert {"content-type", "application/json"} in headers
    end

    test "includes thinking beta flag when thinking option is present" do
      headers = Anthropic.headers(thinking: %{type: "enabled", budget_tokens: 4096})

      assert {"anthropic-beta", "interleaved-thinking-2025-05-14"} in headers
    end

    test "includes thinking beta flag when reasoning_effort is present" do
      headers = Anthropic.headers(reasoning_effort: :high)

      assert {"anthropic-beta", "interleaved-thinking-2025-05-14"} in headers
    end

    test "combines multiple beta flags" do
      headers =
        Anthropic.headers(
          thinking: %{type: "enabled", budget_tokens: 4096},
          anthropic_context_1m: true
        )

      beta_header = Enum.find(headers, fn {k, _} -> k == "anthropic-beta" end)
      assert beta_header != nil
      {_, beta_value} = beta_header
      assert "interleaved-thinking-2025-05-14" in String.split(beta_value, ",")
      assert "context-1m-2025-08-07" in String.split(beta_value, ",")
    end

    test "includes the 1m context beta flag when requested" do
      headers = Anthropic.headers(anthropic_context_1m: true)

      assert {"anthropic-beta", beta_value} = List.keyfind(headers, "anthropic-beta", 0)
      assert "context-1m-2025-08-07" in String.split(beta_value, ",")
    end

    test "includes context management and compaction beta flags when requested" do
      headers =
        Anthropic.headers(
          context_management: %{
            edits: [
              %{type: "clear_thinking_20251015"},
              %{type: "compact_20260112"}
            ]
          }
        )

      assert {"anthropic-beta", beta_value} = List.keyfind(headers, "anthropic-beta", 0)
      beta_flags = String.split(beta_value, ",")
      assert "context-management-2025-06-27" in beta_flags
      assert "compact-2026-01-12" in beta_flags
    end

    test "accepts custom Anthropic beta headers" do
      headers =
        Anthropic.headers(
          anthropic_context_1m: true,
          anthropic_beta_headers: ["structured-outputs-2025-11-13", "context-1m-2025-08-07"]
        )

      assert {"anthropic-beta", beta_value} = List.keyfind(headers, "anthropic-beta", 0)
      assert "context-1m-2025-08-07" in String.split(beta_value, ",")
      assert "structured-outputs-2025-11-13" in String.split(beta_value, ",")
      assert Enum.count(String.split(beta_value, ","), &(&1 == "context-1m-2025-08-07")) == 1
    end

    test "includes beta headers for files surfaces only" do
      headers =
        Anthropic.headers(
          anthropic_files_api: true,
          mcp_servers: [ReqLlmNext.Anthropic.mcp_server("https://mcp.example.com")],
          tools: [ReqLlmNext.Anthropic.code_execution_tool()]
        )

      assert {"anthropic-beta", beta_value} = List.keyfind(headers, "anthropic-beta", 0)
      beta_flags = String.split(beta_value, ",")
      assert "files-api-2025-04-14" in beta_flags
    end

    test "does not include GA tool beta headers for MCP, code execution, or computer use" do
      headers =
        Anthropic.headers(
          mcp_servers: [ReqLlmNext.Anthropic.mcp_server("https://mcp.example.com")],
          tools: [
            ReqLlmNext.Anthropic.code_execution_tool(),
            ReqLlmNext.Anthropic.computer_use_tool(version: :latest, enable_zoom: true)
          ]
        )

      refute Enum.any?(headers, fn
               {"anthropic-beta", value} ->
                 beta_flags = String.split(value, ",")

                 "mcp-client-2025-11-20" in beta_flags or
                   "code-execution-2025-08-25" in beta_flags or
                   "computer-use-2025-11-24" in beta_flags or
                   "computer-use-2025-01-24" in beta_flags

               _ ->
                 false
             end)
    end

    test "does not include computer-use beta header for bash and text editor alone" do
      headers =
        Anthropic.headers(
          tools: [ReqLlmNext.Anthropic.bash_tool(), ReqLlmNext.Anthropic.text_editor_tool()]
        )

      refute Enum.any?(headers, fn
               {"anthropic-beta", value} ->
                 "computer-use-2025-11-24" in String.split(value, ",") or
                   "computer-use-2025-01-24" in String.split(value, ",")

               _ ->
                 false
             end)
    end

    test "does not include dynamic web beta headers for GA web search" do
      headers =
        Anthropic.headers(
          tools: [
            ReqLlmNext.Anthropic.web_search_tool(
              dynamic_filtering: true,
              allowed_callers: ["direct"]
            )
          ]
        )

      refute Enum.any?(headers, fn
               {"anthropic-beta", value} ->
                 "code-execution-web-tools-2026-02-09" in String.split(value, ",")

               _ ->
                 false
             end)
    end

    test "does not include beta header when no beta features enabled" do
      headers = Anthropic.headers([])

      refute Enum.any?(headers, fn {k, _} -> k == "anthropic-beta" end)
    end
  end

  describe "map_reasoning_effort_to_budget/1" do
    test "maps atom :low to 1024" do
      assert Anthropic.map_reasoning_effort_to_budget(:low) == 1024
    end

    test "maps atom :medium to 2048" do
      assert Anthropic.map_reasoning_effort_to_budget(:medium) == 2048
    end

    test "maps atom :high to 4096" do
      assert Anthropic.map_reasoning_effort_to_budget(:high) == 4096
    end

    test "maps string 'low' to 1024" do
      assert Anthropic.map_reasoning_effort_to_budget("low") == 1024
    end

    test "maps string 'medium' to 2048" do
      assert Anthropic.map_reasoning_effort_to_budget("medium") == 2048
    end

    test "maps string 'high' to 4096" do
      assert Anthropic.map_reasoning_effort_to_budget("high") == 4096
    end

    test "defaults unknown values to medium (2048)" do
      assert Anthropic.map_reasoning_effort_to_budget(:unknown) == 2048
      assert Anthropic.map_reasoning_effort_to_budget("invalid") == 2048
    end
  end

  describe "encode_body/3" do
    test "encodes basic prompt with default max_tokens" do
      model = TestModels.anthropic()
      body = Anthropic.encode_body(model, "Hello!", [])

      assert body.model == "test-model"
      assert body.messages == [%{role: "user", content: "Hello!"}]
      assert body.stream == true
      assert body.max_tokens == 1024
    end

    test "uses provided max_tokens" do
      model = TestModels.anthropic()
      body = Anthropic.encode_body(model, "Hello!", max_tokens: 2048)

      assert body.max_tokens == 2048
    end

    test "includes temperature when provided" do
      model = TestModels.anthropic()
      body = Anthropic.encode_body(model, "Hello!", temperature: 0.7)

      assert body.temperature == 0.7
    end

    test "omits temperature when not provided" do
      model = TestModels.anthropic()
      body = Anthropic.encode_body(model, "Hello!", [])

      refute Map.has_key?(body, :temperature)
    end

    test "omits temperature when thinking mode is enabled" do
      model = TestModels.anthropic()

      body =
        Anthropic.encode_body(model, "Hello!",
          thinking: %{type: "enabled", budget_tokens: 4096},
          temperature: 0.7
        )

      refute Map.has_key?(body, :temperature)
      assert body.thinking == %{type: "enabled", budget_tokens: 4096}
    end

    test "omits temperature when reasoning_effort is set" do
      model = TestModels.anthropic()
      body = Anthropic.encode_body(model, "Hello!", reasoning_effort: :high, temperature: 0.5)

      refute Map.has_key?(body, :temperature)
    end

    test "encodes thinking config from reasoning_effort" do
      model = TestModels.anthropic()
      body = Anthropic.encode_body(model, "Hello!", reasoning_effort: :high)

      assert body.thinking == %{type: "enabled", budget_tokens: 4096}
    end

    test "encodes output_config effort without enabling thinking" do
      model = TestModels.anthropic()
      body = Anthropic.encode_body(model, "Hello!", effort: :medium, temperature: 0.5)

      assert body.output_config == %{effort: "medium"}
      assert body.temperature == 0.5
      refute Map.has_key?(body, :thinking)
    end

    test "encodes thinking config from explicit thinking option" do
      model = TestModels.anthropic()

      body =
        Anthropic.encode_body(model, "Hello!", thinking: %{type: "enabled", budget_tokens: 8192})

      assert body.thinking == %{type: "enabled", budget_tokens: 8192}
    end

    test "encodes context with system message" do
      model = TestModels.anthropic()

      context =
        Context.new([
          Context.system("You are helpful"),
          Context.user("Hello")
        ])

      body = Anthropic.encode_body(model, context, [])

      assert body.system == "You are helpful"
      assert length(body.messages) == 1
      assert hd(body.messages).role == "user"
    end

    test "encodes multi-turn context" do
      model = TestModels.anthropic()

      context =
        Context.new([
          Context.user("Hello"),
          Context.assistant("Hi there!"),
          Context.user("How are you?")
        ])

      body = Anthropic.encode_body(model, context, [])

      assert length(body.messages) == 3
      assert Enum.at(body.messages, 0).role == "user"
      assert Enum.at(body.messages, 1).role == "assistant"
      assert Enum.at(body.messages, 2).role == "user"
    end

    test "encodes tool result messages" do
      model = TestModels.anthropic()

      context =
        Context.new([
          Context.user("What's the weather?"),
          Context.assistant("",
            tool_calls: [ToolCall.new("call_123", "get_weather", ~s({"location":"SF"}))]
          ),
          Context.tool_result("call_123", "Sunny, 72F")
        ])

      body = Anthropic.encode_body(model, context, [])

      tool_msg = Enum.at(body.messages, 2)
      assert tool_msg.role == "user"
      assert [%{type: "tool_result", tool_use_id: "call_123"}] = tool_msg.content
    end

    test "encodes assistant message with tool calls" do
      model = TestModels.anthropic()

      context =
        Context.new([
          Context.user("What's the weather?"),
          Context.assistant("Let me check",
            tool_calls: [ToolCall.new("call_456", "get_weather", ~s({"location":"NYC"}))]
          )
        ])

      body = Anthropic.encode_body(model, context, [])

      assistant_msg = Enum.at(body.messages, 1)
      assert assistant_msg.role == "assistant"

      assert [
               %{type: "text", text: "Let me check"},
               %{
                 type: "tool_use",
                 id: "call_456",
                 name: "get_weather",
                 input: %{"location" => "NYC"}
               }
             ] = assistant_msg.content
    end

    test "encodes tools when provided" do
      model = TestModels.anthropic()

      tool =
        Tool.new!(
          name: "get_weather",
          description: "Get weather",
          parameter_schema: [location: [type: :string, required: true]],
          callback: fn _ -> {:ok, "sunny"} end
        )

      body = Anthropic.encode_body(model, "Hello", tools: [tool])

      assert is_list(body.tools)
      assert length(body.tools) == 1
    end

    test "accepts Anthropic helper tool maps" do
      model = TestModels.anthropic()
      raw_tool = ReqLlmNext.Anthropic.web_search_tool(max_uses: 2)

      body = Anthropic.encode_body(model, "Hello", tools: [raw_tool])

      assert body.tools == [%{name: "web_search", type: "web_search_20250305", max_uses: 2}]
    end

    test "encodes dynamic web search tool versions when requested" do
      model = TestModels.anthropic()
      raw_tool = ReqLlmNext.Anthropic.web_search_tool(dynamic_filtering: true)

      body = Anthropic.encode_body(model, "Hello", tools: [raw_tool])

      assert body.tools == [%{name: "web_search", type: "web_search_20260209"}]
    end

    test "rejects unmarked raw tool maps" do
      model = TestModels.anthropic()
      raw_tool = %{name: "raw_tool", description: "A raw tool", input_schema: %{}}

      assert_raise ArgumentError,
                   ~r/ReqLlmNext.Anthropic helper constructors/,
                   fn ->
                     Anthropic.encode_body(model, "Hello", tools: [raw_tool])
                   end
    end

    test "encodes tool_choice" do
      model = TestModels.anthropic()

      body =
        Anthropic.encode_body(model, "Hello", tool_choice: %{type: "tool", name: "get_weather"})

      assert body.tool_choice == %{type: "tool", name: "get_weather"}
    end

    test "passes through generic tool_choice" do
      model = TestModels.anthropic()

      body = Anthropic.encode_body(model, "Hello", tool_choice: %{type: "auto"})

      assert body.tool_choice == %{type: "auto"}
    end

    test "encodes top-level cache control when caching enabled" do
      model = TestModels.anthropic()

      context =
        Context.new([
          Context.system("You are helpful"),
          Context.user("Hello")
        ])

      body = Anthropic.encode_body(model, context, anthropic_prompt_cache: true)

      assert body.system == "You are helpful"
      assert body.cache_control == %{type: "ephemeral"}
    end

    test "encodes top-level cache control with 1-hour TTL" do
      model = TestModels.anthropic()

      context =
        Context.new([
          Context.system("You are helpful"),
          Context.user("Hello")
        ])

      body =
        Anthropic.encode_body(model, context,
          anthropic_prompt_cache: true,
          anthropic_prompt_cache_ttl: 3600
        )

      assert body.cache_control == %{type: "ephemeral", ttl: "1h"}
    end

    test "encodes image content part" do
      model = TestModels.anthropic()

      context =
        Context.new([
          Context.with_image(:user, "What is this?", "https://example.com/image.png")
        ])

      body = Anthropic.encode_body(model, context, [])

      [msg] = body.messages
      assert length(msg.content) == 2
      [text_part, image_part] = msg.content
      assert text_part == %{type: "text", text: "What is this?"}

      assert image_part == %{
               type: "image",
               source: %{type: "url", url: "https://example.com/image.png"}
             }
    end

    test "encodes binary image content part as base64 source" do
      model = TestModels.anthropic()

      context =
        Context.new([
          Context.user([
            Context.ContentPart.text("What color is this image?"),
            Context.ContentPart.image(<<255, 0, 0>>, "image/png")
          ])
        ])

      body = Anthropic.encode_body(model, context, [])

      [msg] = body.messages
      [_, image_part] = msg.content

      assert image_part == %{
               type: "image",
               source: %{type: "base64", media_type: "image/png", data: "/wAA"}
             }
    end

    test "encodes native structured outputs for Anthropic object plans" do
      model =
        TestModels.anthropic(%{
          extra: %{capabilities: %{structured_outputs: %{supported: true}}}
        })

      body =
        Anthropic.encode_body(
          model,
          "Generate JSON",
          operation: :object,
          compiled_schema: %{schema: [name: [type: :string]]},
          _structured_output_strategy: :native_json_schema
        )

      assert body.output_config.format.type == "json_schema"
      assert body.output_config.format.schema["type"] == "object"
      assert body.output_config.format.schema["properties"]["name"]["type"] == "string"
    end

    test "encodes document file references with citations" do
      model = TestModels.anthropic()

      context =
        Context.new([
          Context.with_document(
            :user,
            "Summarize this document",
            ReqLlmNext.Anthropic.document_file_id("file_123", %{
              title: "Manual",
              citations: %{enabled: true}
            })
          )
        ])

      body = Anthropic.encode_body(model, context, [])

      [message] = body.messages
      [_, document_part] = message.content

      assert document_part.type == "document"
      assert document_part.source == %{type: "file", file_id: "file_123"}
      assert document_part.title == "Manual"
      assert document_part.citations == %{enabled: true}
    end

    test "encodes container uploads for code execution flows" do
      model = TestModels.anthropic()

      context =
        Context.new([
          Context.user([
            ReqLlmNext.Context.ContentPart.text("Analyze this file"),
            ReqLlmNext.Anthropic.container_upload("file_456",
              filename: "data.csv",
              content_type: "text/csv"
            )
          ])
        ])

      body = Anthropic.encode_body(model, context, [])

      [message] = body.messages
      [_, upload_part] = message.content

      assert upload_part == %{type: "container_upload", file_id: "file_456"}
    end

    test "passes through context management and MCP servers" do
      model = TestModels.anthropic()

      mcp_server =
        ReqLlmNext.Anthropic.mcp_server("https://mcp.example.com", name: "remote_tools")

      body =
        Anthropic.encode_body(
          model,
          "Hello",
          context_management: %{compact: true},
          mcp_servers: [mcp_server]
        )

      assert body.context_management == %{compact: true}

      assert body.mcp_servers == [
               %{type: "url", url: "https://mcp.example.com", name: "remote_tools"}
             ]
    end
  end

  describe "options_schema/0" do
    test "returns valid NimbleOptions-style schema" do
      schema = Anthropic.options_schema()

      assert Keyword.has_key?(schema, :max_tokens)
      assert Keyword.has_key?(schema, :temperature)
      assert Keyword.has_key?(schema, :top_p)
      assert Keyword.has_key?(schema, :top_k)
    end

    test "max_tokens has default value" do
      schema = Anthropic.options_schema()
      assert schema[:max_tokens][:default] == 1024
    end
  end

  describe "decode_wire_event/1" do
    test "decodes JSON payloads into raw event maps" do
      assert Anthropic.decode_wire_event(%{
               data: ~s({"type":"content_block_delta","delta":{"text":"Hello"}})
             }) == [%{"type" => "content_block_delta", "delta" => %{"text" => "Hello"}}]
    end

    test "passes through pre-decoded maps" do
      payload = %{"type" => "ping"}
      assert Anthropic.decode_wire_event(%{data: payload}) == [payload]
    end

    test "returns decode errors for invalid JSON" do
      assert [{:decode_error, _}] = Anthropic.decode_wire_event(%{data: "not valid json"})
    end

    test "returns empty list for unknown payload shapes" do
      assert Anthropic.decode_wire_event(%{something: "else"}) == []
    end
  end

  describe "decode_sse_event/2" do
    test "delegates wire payloads through semantic normalization" do
      event = %{data: ~s({"type":"message_stop"})}
      assert Anthropic.decode_sse_event(event, nil) == [nil]
    end
  end
end
