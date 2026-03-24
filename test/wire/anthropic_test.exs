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

    test "includes prompt caching beta flag" do
      headers = Anthropic.headers(anthropic_prompt_cache: true)

      assert {"anthropic-beta", "prompt-caching-2024-07-31"} in headers
    end

    test "combines multiple beta flags" do
      headers =
        Anthropic.headers(
          thinking: %{type: "enabled", budget_tokens: 4096},
          anthropic_prompt_cache: true
        )

      beta_header = Enum.find(headers, fn {k, _} -> k == "anthropic-beta" end)
      assert beta_header != nil
      {_, beta_value} = beta_header
      assert "interleaved-thinking-2025-05-14" in String.split(beta_value, ",")
      assert "prompt-caching-2024-07-31" in String.split(beta_value, ",")
    end

    test "includes the 1m context beta flag when requested" do
      headers = Anthropic.headers(anthropic_context_1m: true)

      assert {"anthropic-beta", beta_value} = List.keyfind(headers, "anthropic-beta", 0)
      assert "context-1m-2025-08-07" in String.split(beta_value, ",")
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

    test "passes through raw tool maps" do
      model = TestModels.anthropic()
      raw_tool = %{name: "raw_tool", description: "A raw tool", input_schema: %{}}

      body = Anthropic.encode_body(model, "Hello", tools: [raw_tool])

      assert body.tools == [raw_tool]
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

    test "encodes system prompt with cache control when caching enabled" do
      model = TestModels.anthropic()

      context =
        Context.new([
          Context.system("You are helpful"),
          Context.user("Hello")
        ])

      body = Anthropic.encode_body(model, context, anthropic_prompt_cache: true)

      assert is_list(body.system)
      [cached_block] = body.system
      assert cached_block.type == "text"
      assert cached_block.text == "You are helpful"
      assert cached_block.cache_control == %{type: "ephemeral"}
    end

    test "encodes system prompt with custom cache TTL" do
      model = TestModels.anthropic()

      context =
        Context.new([
          Context.system("You are helpful"),
          Context.user("Hello")
        ])

      body =
        Anthropic.encode_body(model, context,
          anthropic_prompt_cache: true,
          anthropic_prompt_cache_ttl: 300
        )

      [cached_block] = body.system
      assert cached_block.cache_control == %{type: "ephemeral", ttl: 300}
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
