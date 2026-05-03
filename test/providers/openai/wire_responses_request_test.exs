defmodule ReqLlmNext.Wire.OpenAIResponses.RequestTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Context
  alias ReqLlmNext.TestModels
  alias ReqLlmNext.Wire.OpenAIResponses

  describe "endpoint/0 and path/0" do
    test "returns responses endpoint" do
      assert OpenAIResponses.endpoint() == "/v1/responses"
      assert OpenAIResponses.path() == "/v1/responses"
    end
  end

  describe "options_schema/0" do
    test "returns valid schema with max_output_tokens" do
      schema = OpenAIResponses.options_schema()

      assert Keyword.has_key?(schema, :max_output_tokens)
      assert Keyword.has_key?(schema, :max_completion_tokens)
      assert Keyword.has_key?(schema, :max_tokens)
      assert Keyword.has_key?(schema, :reasoning_effort)
    end
  end

  describe "encode_body/3" do
    test "encodes string prompt as input array" do
      model = TestModels.openai_reasoning()
      body = OpenAIResponses.encode_body(model, "Hello", [])

      assert body.model == "o1-test"
      assert body.stream == true
      assert body.input == [%{role: "user", content: [%{type: "input_text", text: "Hello"}]}]
    end

    test "does not include legacy stream_options usage flag" do
      model = TestModels.openai_reasoning()
      body = OpenAIResponses.encode_body(model, "Hello", [])

      refute Map.has_key?(body, :stream_options)
    end

    test "converts system role to developer role" do
      model = TestModels.openai_reasoning()

      context =
        Context.new([
          Context.system("You are helpful"),
          Context.user("Hello")
        ])

      body = OpenAIResponses.encode_body(model, context, [])

      assert [developer_msg, user_msg] = body.input
      assert developer_msg.role == "developer"
      assert developer_msg.content == [%{type: "input_text", text: "You are helpful"}]
      assert user_msg.role == "user"
    end

    test "uses output_text for assistant messages" do
      model = TestModels.openai_reasoning()

      context =
        Context.new([
          Context.user("Hi"),
          Context.assistant("Hello!")
        ])

      body = OpenAIResponses.encode_body(model, context, [])

      assert [user_msg, assistant_msg] = body.input
      assert user_msg.content == [%{type: "input_text", text: "Hi"}]
      assert assistant_msg.role == "assistant"
      assert assistant_msg.content == [%{type: "output_text", text: "Hello!"}]
    end

    test "encodes tool result messages as function_call_output items" do
      model = TestModels.openai_reasoning()

      context =
        Context.new([
          Context.user("Hello"),
          Context.tool_result("call_123", "Result")
        ])

      body = OpenAIResponses.encode_body(model, context, [])

      assert length(body.input) == 2
      assert Enum.at(body.input, 0).role == "user"

      assert Enum.at(body.input, 1) == %{
               type: "function_call_output",
               call_id: "call_123",
               output: "Result"
             }
    end

    test "encodes assistant tool calls as function_call items" do
      model = TestModels.openai_reasoning()

      tool_call = ReqLlmNext.ToolCall.new("call_abc", "get_weather", ~s({"location":"SF"}))

      context =
        Context.new([
          Context.user("What's the weather?"),
          Context.assistant("", tool_calls: [tool_call])
        ])

      body = OpenAIResponses.encode_body(model, context, [])

      assert Enum.at(body.input, 1) == %{
               type: "function_call",
               call_id: "call_abc",
               name: "get_weather",
               arguments: ~s({"location":"SF"})
             }
    end

    test "encodes image content in user messages" do
      model = TestModels.openai_reasoning()

      context =
        Context.new([
          Context.with_image(:user, "What is this?", "https://example.com/image.png")
        ])

      body = OpenAIResponses.encode_body(model, context, [])

      [msg] = body.input
      assert length(msg.content) == 2
      assert Enum.at(msg.content, 0) == %{type: "input_text", text: "What is this?"}

      assert Enum.at(msg.content, 1) == %{
               type: "input_image",
               image_url: "https://example.com/image.png"
             }
    end

    test "encodes binary image content in user messages" do
      model = TestModels.openai_reasoning()

      context =
        Context.new([
          Context.user([
            Context.ContentPart.text("What color is this image?"),
            Context.ContentPart.image(<<255, 0, 0>>, "image/png")
          ])
        ])

      body = OpenAIResponses.encode_body(model, context, [])

      [msg] = body.input
      assert length(msg.content) == 2

      assert Enum.at(msg.content, 1) == %{
               type: "input_image",
               image_url: "data:image/png;base64,/wAA"
             }
    end

    test "encodes inline file content in user messages" do
      model = TestModels.openai_reasoning()

      context =
        Context.new([
          Context.user([
            Context.ContentPart.text("Summarize this PDF"),
            Context.ContentPart.file("pdf-bytes", "manual.pdf", "application/pdf")
          ])
        ])

      body = OpenAIResponses.encode_body(model, context, [])

      [msg] = body.input

      assert Enum.at(msg.content, 1) == %{
               type: "input_file",
               filename: "manual.pdf",
               file_data: "data:application/pdf;base64,#{Base.encode64("pdf-bytes")}"
             }
    end

    test "encodes file id references from canonical document parts" do
      model = TestModels.openai_reasoning()

      context =
        Context.new([
          Context.user([
            Context.ContentPart.text("Summarize this file"),
            Context.ContentPart.document_file_id("file-123")
          ])
        ])

      body = OpenAIResponses.encode_body(model, context, [])

      [msg] = body.input

      assert Enum.at(msg.content, 1) == %{
               type: "input_file",
               file_id: "file-123"
             }
    end

    test "encodes file url references from canonical document parts" do
      model = TestModels.openai_reasoning()

      context =
        Context.new([
          Context.user([
            Context.ContentPart.text("Summarize this remote PDF"),
            Context.ContentPart.document_url("https://example.com/manual.pdf")
          ])
        ])

      body = OpenAIResponses.encode_body(model, context, [])

      [msg] = body.input

      assert Enum.at(msg.content, 1) == %{
               type: "input_file",
               file_url: "https://example.com/manual.pdf"
             }
    end

    test "includes reasoning config when effort specified" do
      model = TestModels.openai_reasoning()
      body = OpenAIResponses.encode_body(model, "Hello", reasoning_effort: :high)

      assert body.reasoning == %{effort: "high"}
    end

    test "accepts string reasoning effort" do
      model = TestModels.openai_reasoning()
      body = OpenAIResponses.encode_body(model, "Hello", reasoning_effort: "medium")

      assert body.reasoning == %{effort: "medium"}
    end

    test "ignores invalid reasoning effort" do
      model = TestModels.openai_reasoning()
      body = OpenAIResponses.encode_body(model, "Hello", reasoning_effort: 123)

      refute Map.has_key?(body, :reasoning)
    end

    test "uses max_output_tokens instead of max_tokens" do
      model = TestModels.openai_reasoning()
      body = OpenAIResponses.encode_body(model, "Hello", max_tokens: 1000)

      assert body.max_output_tokens == 1000
      refute Map.has_key?(body, :max_tokens)
    end

    test "prioritizes max_output_tokens over alternatives" do
      model = TestModels.openai_reasoning()

      body =
        OpenAIResponses.encode_body(model, "Hello",
          max_output_tokens: 100,
          max_completion_tokens: 200,
          max_tokens: 300
        )

      assert body.max_output_tokens == 100
    end

    test "uses max_completion_tokens when max_output_tokens not provided" do
      model = TestModels.openai_reasoning()

      body =
        OpenAIResponses.encode_body(model, "Hello",
          max_completion_tokens: 200,
          max_tokens: 300
        )

      assert body.max_output_tokens == 200
    end

    test "includes prompt caching request controls when provided" do
      model = TestModels.openai_reasoning()

      body =
        OpenAIResponses.encode_body(model, "Hello",
          prompt_cache_key: "shared-prefix",
          prompt_cache_retention: :in_memory
        )

      assert body.prompt_cache_key == "shared-prefix"
      assert body.prompt_cache_retention == "in_memory"
    end

    test "encodes tools in responses format" do
      model = TestModels.openai_reasoning()

      tool =
        ReqLlmNext.Tool.new!(
          name: "get_weather",
          description: "Get weather",
          parameter_schema: [location: [type: :string, required: true]],
          callback: fn _ -> {:ok, "sunny"} end
        )

      body = OpenAIResponses.encode_body(model, "Hello", tools: [tool])

      assert [encoded_tool] = body.tools
      assert encoded_tool.type == "function"
      assert encoded_tool.name == "get_weather"
      assert encoded_tool.description == "Get weather"
      assert encoded_tool.strict == false
    end

    test "respects explicit strict tools" do
      model = TestModels.openai_reasoning()

      tool =
        ReqLlmNext.Tool.new!(
          name: "get_weather",
          description: "Get weather",
          parameter_schema: [location: [type: :string, required: true]],
          callback: fn _ -> {:ok, "sunny"} end,
          strict: true
        )

      body = OpenAIResponses.encode_body(model, "Hello", tools: [tool])

      assert [encoded_tool] = body.tools
      assert encoded_tool.strict == true
    end

    test "encodes OpenAI built-in helper tools" do
      model = TestModels.openai_reasoning()

      body =
        OpenAIResponses.encode_body(model, "Search the web",
          tools: [ReqLlmNext.OpenAI.web_search_tool()]
        )

      assert body.tools == [%{type: "web_search"}]
    end

    test "rejects raw tool maps" do
      model = TestModels.openai_reasoning()
      raw_tool = %{type: "function", name: "raw", description: "Raw tool"}

      error =
        assert_raise ArgumentError, fn ->
          OpenAIResponses.encode_body(model, "Hello", tools: [raw_tool])
        end

      assert error.message =~ "ReqLlmNext.Tool values"
    end

    test "does not add tools key when tools is empty list" do
      model = TestModels.openai_reasoning()
      body = OpenAIResponses.encode_body(model, "Hello", tools: [])

      refute Map.has_key?(body, :tools)
    end

    test "encodes tool_choice variants" do
      model = TestModels.openai_reasoning()

      assert OpenAIResponses.encode_body(model, "Hello", tool_choice: :auto).tool_choice == "auto"

      assert OpenAIResponses.encode_body(model, "Hello", tool_choice: "auto").tool_choice ==
               "auto"

      assert OpenAIResponses.encode_body(model, "Hello", tool_choice: :none).tool_choice == "none"

      assert OpenAIResponses.encode_body(model, "Hello", tool_choice: "none").tool_choice ==
               "none"

      assert OpenAIResponses.encode_body(model, "Hello", tool_choice: :required).tool_choice ==
               "required"

      assert OpenAIResponses.encode_body(model, "Hello", tool_choice: "required").tool_choice ==
               "required"
    end

    test "passes through built-in tool response controls" do
      model = TestModels.openai_reasoning()

      body =
        OpenAIResponses.encode_body(model, "Search the web",
          include: [ReqLlmNext.OpenAI.web_search_sources_include()],
          truncation: "auto"
        )

      assert body.include == ["web_search_call.action.sources"]
      assert body.truncation == "auto"
    end

    test "encodes specific tool choice with function format" do
      model = TestModels.openai_reasoning()

      body =
        OpenAIResponses.encode_body(model, "Hello",
          tool_choice: %{type: "function", function: %{name: "get_weather"}}
        )

      assert body.tool_choice == %{type: "function", name: "get_weather"}
    end

    test "encodes specific tool choice with tool format" do
      model = TestModels.openai_reasoning()

      body =
        OpenAIResponses.encode_body(model, "Hello",
          tool_choice: %{type: "tool", name: "get_weather"}
        )

      assert body.tool_choice == %{type: "function", name: "get_weather"}
    end

    test "ignores unknown tool_choice values" do
      model = TestModels.openai_reasoning()
      body = OpenAIResponses.encode_body(model, "Hello", tool_choice: :unknown)

      refute Map.has_key?(body, :tool_choice)
    end

    test "omits nil values" do
      model = TestModels.openai_reasoning()
      body = OpenAIResponses.encode_body(model, "Hello", [])

      refute Map.has_key?(body, :max_output_tokens)
      refute Map.has_key?(body, :reasoning)
      refute Map.has_key?(body, :tools)
    end

    test "encodes response format for object operation with schema" do
      model = TestModels.openai_reasoning()

      schema = [
        name: [type: :string, required: true],
        age: [type: :integer]
      ]

      compiled = %{schema: schema}

      body =
        OpenAIResponses.encode_body(model, "Hello",
          operation: :object,
          compiled_schema: compiled,
          _structured_output_strategy: :native_json_schema
        )

      assert body.text.format.type == "json_schema"
      assert body.text.format.name == "object"
      assert body.text.format.strict == true
      assert is_map(body.text.format.schema)
    end

    test "omits native response format for prompt-and-parse object plans" do
      model = TestModels.openai_reasoning()

      body =
        OpenAIResponses.encode_body(model, "Hello",
          operation: :object,
          compiled_schema: %{schema: [name: [type: :string]]},
          _structured_output_strategy: :prompt_and_parse
        )

      refute Map.has_key?(body, :text)
    end

    test "does not add response format when operation is not object" do
      model = TestModels.openai_reasoning()
      body = OpenAIResponses.encode_body(model, "Hello", operation: :text)

      refute Map.has_key?(body, :text)
    end
  end

  describe "encode_websocket_event/3" do
    test "encodes a response.create event for websocket mode" do
      model = TestModels.openai_reasoning()
      body = OpenAIResponses.encode_websocket_event(model, "Hello", [])

      assert body.type == "response.create"
      assert body.model == "o1-test"

      assert body.input == [
               %{
                 type: "message",
                 role: "user",
                 content: [%{type: "input_text", text: "Hello"}]
               }
             ]

      refute Map.has_key?(body, :stream)
    end

    test "includes websocket-only continuation fields when provided" do
      model = TestModels.openai_reasoning()

      body =
        OpenAIResponses.encode_websocket_event(model, "Hello",
          previous_response_id: "resp_123",
          store: false,
          generate: false
        )

      assert body.previous_response_id == "resp_123"
      assert body.store == false
      assert body.generate == false
    end

    test "preserves function call output item types in websocket events" do
      model = TestModels.openai_reasoning()

      context =
        Context.new([
          Context.user("Hello"),
          Context.tool_result("call_123", "Result")
        ])

      body = OpenAIResponses.encode_websocket_event(model, context, [])

      assert Enum.at(body.input, 0).type == "message"

      assert Enum.at(body.input, 1) == %{
               type: "function_call_output",
               call_id: "call_123",
               output: "Result"
             }
    end

    test "includes prompt caching request controls in websocket events" do
      model = TestModels.openai_reasoning()

      body =
        OpenAIResponses.encode_websocket_event(model, "Hello",
          prompt_cache_key: "shared-prefix",
          prompt_cache_retention: "24h"
        )

      assert body.prompt_cache_key == "shared-prefix"
      assert body.prompt_cache_retention == "24h"
    end

    test "encodes built-in tools and include controls in websocket events" do
      model = TestModels.openai_reasoning()

      body =
        OpenAIResponses.encode_websocket_event(model, "Search the web",
          tools: [ReqLlmNext.OpenAI.web_search_tool(version: :preview)],
          include: [ReqLlmNext.OpenAI.web_search_sources_include()],
          truncation: "auto"
        )

      assert body.tools == [%{type: "web_search_preview"}]
      assert body.include == ["web_search_call.action.sources"]
      assert body.truncation == "auto"
    end

    test "includes temperature in websocket events when explicitly provided" do
      model = TestModels.openai_reasoning()
      body = OpenAIResponses.encode_websocket_event(model, "Hello", temperature: 0.7)

      assert body.temperature == 0.7
    end
  end
end
