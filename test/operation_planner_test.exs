defmodule ReqLlmNext.OperationPlannerTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.{
    Anthropic,
    Context,
    Error,
    ExecutionModules,
    OperationPlanner,
    TestModels,
    Tool
  }

  describe "plan/4 for anthropic starter slice" do
    test "builds a deterministic text plan for claude-haiku-4-5" do
      {:ok, model} = LLMDB.model("anthropic:claude-haiku-4-5")

      assert {:ok, plan} =
               OperationPlanner.plan(model, :text, "Hello", _stream?: true)

      assert plan.provider == :anthropic
      assert plan.model.model_id == "claude-haiku-4-5-20251001"
      assert plan.mode.operation == :text
      assert plan.mode.stream? == true
      assert plan.surface.id == :anthropic_messages_text_http_sse
      assert plan.semantic_protocol == :anthropic_messages
      assert plan.wire_format == :anthropic_messages_sse_json
      assert plan.transport == :http_sse
      assert ReqLlmNext.Adapters.Anthropic.Thinking in plan.plan_adapters
      assert plan.parameter_values == %{}
    end

    test "supports object mode through native structured-output surfaces" do
      {:ok, model} = LLMDB.model("anthropic:claude-haiku-4-5")

      assert {:ok, plan} =
               OperationPlanner.plan(
                 model,
                 :object,
                 "Return JSON",
                 compiled_schema: %{schema: %{}}
               )

      assert plan.mode.structured_output? == true
      assert plan.surface.id == :anthropic_messages_object_http_sse
      assert plan.surface.features.structured_output == :native_json_schema
    end

    test "accepts Anthropic provider-native helper tools on Anthropic surfaces" do
      model = TestModels.anthropic()

      assert {:ok, plan} =
               OperationPlanner.plan(
                 model,
                 :text,
                 "Hello",
                 tools: [Anthropic.web_search_tool(max_uses: 2)]
               )

      assert [%{name: "web_search", type: "web_search_20250305"}] = plan.parameter_values.tools
    end

    test "preserves canonical ReqLlmNext.Tool values on Anthropic surfaces" do
      model = TestModels.anthropic()

      tool =
        Tool.new!(
          name: "get_weather",
          description: "Get weather",
          parameter_schema: [location: [type: :string, required: true]],
          callback: fn _ -> {:ok, "sunny"} end
        )

      assert {:ok, plan} = OperationPlanner.plan(model, :text, "Hello", tools: [tool])
      assert [^tool] = plan.parameter_values.tools
    end

    test "derives anthropic_files_api during planning for document inputs" do
      model =
        TestModels.anthropic(%{
          extra: %{capabilities: %{code_execution: %{supported: true}}}
        })

      prompt =
        Context.new([
          Context.user([
            Anthropic.document_file_id("file_123", %{title: "Manual"})
          ])
        ])

      assert {:ok, plan} = OperationPlanner.plan(model, :text, prompt)
      assert plan.parameter_values.anthropic_files_api == true
    end
  end

  describe "plan/4 for openai starter slice" do
    test "builds a responses-based text plan for gpt-4o-mini" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")

      assert {:ok, plan} =
               OperationPlanner.plan(model, :text, "Hello", max_tokens: 100, _stream?: true)

      assert plan.provider == :openai
      assert plan.model.model_id == "gpt-4o-mini"
      assert plan.mode.operation == :text
      assert plan.surface.id == :openai_responses_text_http_sse
      assert plan.semantic_protocol == :openai_responses
      assert plan.wire_format == :openai_responses_sse_json
      assert plan.transport == :http_sse
      assert plan.plan_adapters == []
      refute ReqLlmNext.Adapters.OpenAI.Reasoning in plan.plan_adapters
      assert plan.parameter_values.max_tokens == 100
    end

    test "builds a native structured-output object plan for gpt-4o-mini" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")

      assert {:ok, plan} =
               OperationPlanner.plan(
                 model,
                 :object,
                 "Return JSON",
                 compiled_schema: %{schema: %{}}
               )

      assert plan.mode.structured_output? == true
      assert plan.surface.id == :openai_responses_object_http_sse
      assert plan.surface.features.structured_output == :native_json_schema
    end

    test "honors explicit websocket transport selection for structured object plans" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")

      assert {:ok, plan} =
               OperationPlanner.plan(
                 model,
                 :object,
                 "Return JSON",
                 compiled_schema: %{schema: %{}},
                 transport: :websocket
               )

      assert plan.surface.id == :openai_responses_object_websocket
      assert plan.wire_format == :openai_responses_ws_json
      assert plan.transport == :websocket
    end

    test "supports explicit websocket transport selection for responses models" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")

      assert {:ok, plan} =
               OperationPlanner.plan(
                 model,
                 :text,
                 "Hello",
                 transport: :websocket,
                 _stream?: true
               )

      assert plan.surface.id == :openai_responses_text_websocket
      assert plan.wire_format == :openai_responses_ws_json
      assert plan.transport == :websocket
      assert plan.surface.fallback_ids == [:openai_responses_text_http_sse]
      assert plan.plan_adapters == []
    end

    test "prefers persistent-session surfaces when session mode is preferred" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")

      assert {:ok, plan} =
               OperationPlanner.plan(
                 model,
                 :text,
                 "Hello",
                 session: :preferred
               )

      assert plan.surface.id == :openai_responses_text_websocket
      assert plan.transport == :websocket
    end

    test "requires persistent-session surfaces when session mode is required" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")

      assert {:ok, plan} =
               OperationPlanner.plan(
                 model,
                 :text,
                 "Hello",
                 session: :required
               )

      assert plan.surface.id == :openai_responses_text_websocket
      assert plan.transport == :websocket
    end

    test "rejects temperature on the websocket responses surface" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")

      assert {:error, %ReqLlmNext.Error.Invalid.Parameter{} = error} =
               OperationPlanner.plan(
                 model,
                 :text,
                 "Hello",
                 transport: :websocket,
                 temperature: 0.7
               )

      assert Exception.message(error) =~ "temperature is not supported"
    end

    test "rejects Anthropic provider-native helper tools on OpenAI surfaces" do
      model = TestModels.openai()

      assert {:error, %Error.Invalid.Parameter{} = error} =
               OperationPlanner.plan(
                 model,
                 :text,
                 "Hello",
                 tools: [Anthropic.web_search_tool()]
               )

      assert Exception.message(error) =~ "ReqLlmNext.Tool values on non-Anthropic surfaces"
    end

    test "rejects raw tool maps on OpenAI surfaces" do
      model = TestModels.openai()

      assert {:error, %Error.Invalid.Parameter{} = error} =
               OperationPlanner.plan(
                 model,
                 :text,
                 "Hello",
                 tools: [[type: "function"] |> Enum.into(%{})]
               )

      assert Exception.message(error) =~ "ReqLlmNext.Tool values on non-Anthropic surfaces"
    end

    test "preserves canonical ReqLlmNext.Tool values on OpenAI surfaces" do
      model = TestModels.openai()

      tool =
        Tool.new!(
          name: "get_weather",
          description: "Get weather",
          parameter_schema: [location: [type: :string, required: true]],
          callback: fn _ -> {:ok, "sunny"} end
        )

      assert {:ok, plan} =
               OperationPlanner.plan(
                 model,
                 :text,
                 "Hello",
                 tools: [tool]
               )

      assert [^tool] = plan.parameter_values.tools
    end

    test "rejects Anthropic MCP connectors on OpenAI surfaces" do
      model = TestModels.openai()

      assert {:error, %Error.Invalid.Parameter{} = error} =
               OperationPlanner.plan(
                 model,
                 :text,
                 "Hello",
                 mcp_servers: [Anthropic.mcp_server("https://mcp.example.com")]
               )

      assert Exception.message(error) =~ "mcp_servers are only supported on Anthropic surfaces"
    end
  end

  describe "ExecutionModules.resolve/1" do
    test "maps openai responses plans to the declared runtime modules" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")
      {:ok, plan} = OperationPlanner.plan(model, :text, "Hello")

      assert %{
               provider_mod: provider_mod,
               protocol_mod: protocol_mod,
               wire_mod: wire_mod,
               transport_mod: transport_mod
             } =
               ExecutionModules.resolve(plan)

      assert provider_mod == ReqLlmNext.Providers.OpenAI
      assert protocol_mod == ReqLlmNext.SemanticProtocols.OpenAIResponses
      assert wire_mod == ReqLlmNext.Wire.OpenAIResponses
      assert transport_mod == ReqLlmNext.Transports.HTTPStream
    end

    test "maps openai websocket plans to the websocket transport module" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")
      {:ok, plan} = OperationPlanner.plan(model, :text, "Hello", transport: :websocket)

      assert %{
               provider_mod: provider_mod,
               protocol_mod: protocol_mod,
               wire_mod: wire_mod,
               transport_mod: transport_mod
             } =
               ExecutionModules.resolve(plan)

      assert provider_mod == ReqLlmNext.Providers.OpenAI
      assert protocol_mod == ReqLlmNext.SemanticProtocols.OpenAIResponses
      assert wire_mod == ReqLlmNext.Wire.OpenAIResponses
      assert transport_mod == ReqLlmNext.Transports.OpenAIResponsesWebSocket
    end

    test "maps anthropic plans to the declared runtime modules" do
      {:ok, model} = LLMDB.model("anthropic:claude-haiku-4-5")
      {:ok, plan} = OperationPlanner.plan(model, :text, "Hello")

      assert %{
               provider_mod: provider_mod,
               protocol_mod: protocol_mod,
               wire_mod: wire_mod,
               transport_mod: transport_mod
             } =
               ExecutionModules.resolve(plan)

      assert provider_mod == ReqLlmNext.Providers.Anthropic
      assert protocol_mod == ReqLlmNext.SemanticProtocols.AnthropicMessages
      assert wire_mod == ReqLlmNext.Wire.Anthropic
      assert transport_mod == ReqLlmNext.Transports.HTTPStream
    end

    test "maps embedding plans to the explicit HTTP request transport" do
      model = TestModels.openai_embedding()
      {:ok, plan} = OperationPlanner.plan(model, :embed, "hello")

      assert %{
               provider_mod: provider_mod,
               protocol_mod: protocol_mod,
               wire_mod: wire_mod,
               transport_mod: transport_mod
             } = ExecutionModules.resolve(plan)

      assert provider_mod == ReqLlmNext.Providers.OpenAI
      assert protocol_mod == nil
      assert wire_mod == ReqLlmNext.Wire.OpenAIEmbeddings
      assert transport_mod == ReqLlmNext.Transports.HTTPRequest
    end
  end
end
