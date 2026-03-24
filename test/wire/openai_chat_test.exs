defmodule ReqLlmNext.Wire.OpenAIChatTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Context
  alias ReqLlmNext.Context.ContentPart
  alias ReqLlmNext.TestModels
  alias ReqLlmNext.Tool
  alias ReqLlmNext.ToolCall
  alias ReqLlmNext.Wire.OpenAIChat

  describe "endpoint/0" do
    test "returns chat completions endpoint" do
      assert OpenAIChat.endpoint() == "/chat/completions"
    end
  end

  describe "encode_body/3" do
    test "encodes basic prompt" do
      model = TestModels.openai()
      body = OpenAIChat.encode_body(model, "Hello!", [])

      assert body.model == "test-model"
      assert body.messages == [%{role: "user", content: "Hello!"}]
      assert body.stream == true
      assert body.stream_options == %{include_usage: true}
    end

    test "includes max_tokens when provided" do
      model = TestModels.openai()
      body = OpenAIChat.encode_body(model, "Hello!", max_tokens: 100)

      assert body.max_tokens == 100
    end

    test "includes temperature when provided" do
      model = TestModels.openai()
      body = OpenAIChat.encode_body(model, "Hello!", temperature: 0.5)

      assert body.temperature == 0.5
    end

    test "includes both max_tokens and temperature" do
      model = TestModels.openai()
      body = OpenAIChat.encode_body(model, "Hello!", max_tokens: 200, temperature: 0.8)

      assert body.max_tokens == 200
      assert body.temperature == 0.8
    end

    test "omits nil values" do
      model = TestModels.openai()
      body = OpenAIChat.encode_body(model, "Hello!", [])

      refute Map.has_key?(body, :max_tokens)
      refute Map.has_key?(body, :temperature)
    end

    test "encodes Context with multiple messages" do
      model = TestModels.openai()

      context =
        Context.new([
          Context.system("You are helpful"),
          Context.user("Hello"),
          Context.assistant("Hi there!")
        ])

      body = OpenAIChat.encode_body(model, context, [])

      assert length(body.messages) == 3
      assert Enum.at(body.messages, 0).role == "system"
      assert Enum.at(body.messages, 1).role == "user"
      assert Enum.at(body.messages, 2).role == "assistant"
    end

    test "encodes tool message" do
      model = TestModels.openai()

      context =
        Context.new([
          Context.user("What's the weather?"),
          Context.tool_result("call_123", "72°F and sunny")
        ])

      body = OpenAIChat.encode_body(model, context, [])

      tool_msg = Enum.at(body.messages, 1)
      assert tool_msg.role == "tool"
      assert tool_msg.tool_call_id == "call_123"
      assert tool_msg.content == "72°F and sunny"
    end

    test "encodes assistant message with tool calls" do
      model = TestModels.openai()

      tool_call = ToolCall.new("call_abc", "get_weather", ~s({"location":"SF"}))

      context =
        Context.new([
          Context.user("What's the weather?"),
          Context.assistant("", tool_calls: [tool_call])
        ])

      body = OpenAIChat.encode_body(model, context, [])

      assistant_msg = Enum.at(body.messages, 1)
      assert assistant_msg.role == "assistant"
      assert length(assistant_msg.tool_calls) == 1
      assert Enum.at(assistant_msg.tool_calls, 0).id == "call_abc"
      assert Enum.at(assistant_msg.tool_calls, 0).type == "function"
      assert Enum.at(assistant_msg.tool_calls, 0).function.name == "get_weather"
      assert Enum.at(assistant_msg.tool_calls, 0).function.arguments == ~s({"location":"SF"})
    end

    test "encodes multi-part content with text only" do
      model = TestModels.openai()

      context =
        Context.new([
          Context.user([ContentPart.text("Hello")])
        ])

      body = OpenAIChat.encode_body(model, context, [])

      assert Enum.at(body.messages, 0).content == "Hello"
    end

    test "encodes multi-part content with image URL" do
      model = TestModels.openai()

      context =
        Context.new([
          Context.user([
            ContentPart.text("What's in this image?"),
            ContentPart.image_url("https://example.com/img.png")
          ])
        ])

      body = OpenAIChat.encode_body(model, context, [])

      content = Enum.at(body.messages, 0).content
      assert is_list(content)
      assert length(content) == 2
      assert Enum.at(content, 0) == %{type: "text", text: "What's in this image?"}

      assert Enum.at(content, 1) == %{
               type: "image_url",
               image_url: %{url: "https://example.com/img.png"}
             }
    end

    test "encodes binary image content as data URI" do
      model = TestModels.openai()

      context =
        Context.new([
          Context.user([
            ContentPart.text("What color is this image?"),
            ContentPart.image(<<255, 0, 0>>, "image/png")
          ])
        ])

      body = OpenAIChat.encode_body(model, context, [])

      content = Enum.at(body.messages, 0).content
      assert is_list(content)

      assert Enum.at(content, 1) == %{
               type: "image_url",
               image_url: %{url: "data:image/png;base64,/wAA"}
             }
    end

    test "includes tools when provided" do
      model = TestModels.openai()

      {:ok, tool} =
        Tool.new(
          name: "get_weather",
          description: "Get current weather",
          parameter_schema: [location: [type: :string, required: true]],
          callback: fn _ -> {:ok, "sunny"} end
        )

      body = OpenAIChat.encode_body(model, "Hello", tools: [tool])

      assert Map.has_key?(body, :tools)
      assert length(body.tools) == 1
      assert Enum.at(body.tools, 0)["type"] == "function"
      assert Enum.at(body.tools, 0)["function"]["name"] == "get_weather"
    end

    test "includes raw tool maps when provided" do
      model = TestModels.openai()

      raw_tool = %{
        "type" => "function",
        "function" => %{
          "name" => "search",
          "description" => "Search the web",
          "parameters" => %{"type" => "object", "properties" => %{}}
        }
      }

      body = OpenAIChat.encode_body(model, "Hello", tools: [raw_tool])

      assert Enum.at(body.tools, 0) == raw_tool
    end

    test "omits tools when empty list" do
      model = TestModels.openai()
      body = OpenAIChat.encode_body(model, "Hello", tools: [])

      refute Map.has_key?(body, :tools)
    end

    test "includes tool_choice when provided" do
      model = TestModels.openai()
      body = OpenAIChat.encode_body(model, "Hello", tool_choice: "auto")

      assert body.tool_choice == "auto"
    end

    test "transforms tool_choice with type and name" do
      model = TestModels.openai()

      body =
        OpenAIChat.encode_body(model, "Hello", tool_choice: %{type: "tool", name: "get_weather"})

      assert body.tool_choice == %{type: "function", function: %{name: "get_weather"}}
    end

    test "includes response_format for object operation with schema" do
      model = TestModels.openai()

      schema = [name: [type: :string, required: true], age: [type: :integer]]
      compiled_schema = %{schema: schema}

      body =
        OpenAIChat.encode_body(model, "Hello",
          operation: :object,
          compiled_schema: compiled_schema,
          _structured_output_strategy: :native_json_schema
        )

      assert Map.has_key?(body, :response_format)
      assert body.response_format.type == "json_schema"
      assert body.response_format.json_schema.name == "object"
      assert body.response_format.json_schema.strict == true
      assert body.response_format.json_schema.schema["type"] == "object"
    end

    test "omits response_format for non-object operations" do
      model = TestModels.openai()
      body = OpenAIChat.encode_body(model, "Hello", operation: :text)

      refute Map.has_key?(body, :response_format)
    end

    test "omits response_format for prompt-and-parse object plans" do
      model = TestModels.openai()

      body =
        OpenAIChat.encode_body(model, "Hello",
          operation: :object,
          compiled_schema: %{schema: [name: [type: :string]]},
          _structured_output_strategy: :prompt_and_parse
        )

      refute Map.has_key?(body, :response_format)
    end
  end

  describe "options_schema/0" do
    test "returns valid NimbleOptions-style schema" do
      schema = OpenAIChat.options_schema()

      assert Keyword.has_key?(schema, :max_tokens)
      assert Keyword.has_key?(schema, :temperature)
      assert Keyword.has_key?(schema, :top_p)
      assert Keyword.has_key?(schema, :frequency_penalty)
      assert Keyword.has_key?(schema, :presence_penalty)
    end
  end

  describe "decode_wire_event/1" do
    test "returns :done for [DONE] events" do
      assert OpenAIChat.decode_wire_event(%{data: "[DONE]"}) == [:done]
    end

    test "decodes JSON payloads into raw event maps" do
      assert OpenAIChat.decode_wire_event(%{
               data: ~s({"choices":[{"delta":{"content":"Hello"}}]})
             }) == [%{"choices" => [%{"delta" => %{"content" => "Hello"}}]}]
    end

    test "passes through decoded maps" do
      payload = %{"usage" => %{"prompt_tokens" => 10}}
      assert OpenAIChat.decode_wire_event(%{data: payload}) == [payload]
    end

    test "returns decode errors for invalid JSON" do
      assert [{:decode_error, _}] = OpenAIChat.decode_wire_event(%{data: "not valid json"})
    end

    test "returns empty list for unknown payload shapes" do
      assert OpenAIChat.decode_wire_event(%{something: "else"}) == []
    end
  end

  describe "decode_sse_event/2" do
    test "delegates wire payloads through semantic normalization" do
      event = %{data: ~s({"choices":[{"delta":{"content":"Hello"}}]})}
      assert OpenAIChat.decode_sse_event(event, nil) == ["Hello"]
    end
  end
end
