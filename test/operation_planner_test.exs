defmodule ReqLlmNext.OperationPlannerTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.{
    ExecutionModules,
    OperationPlanner
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

    test "supports object mode through prompt-and-parse surfaces" do
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
      assert plan.surface.features.structured_output == :prompt_and_parse
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
      assert ReqLlmNext.Adapters.OpenAI.GPT4oMini in plan.plan_adapters
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
    end
  end

  describe "ExecutionModules.resolve/1" do
    test "maps openai responses plans to the current bridge modules" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")
      {:ok, plan} = OperationPlanner.plan(model, :text, "Hello")

      assert %{provider_mod: provider_mod, wire_mod: wire_mod, transport_mod: transport_mod} =
               ExecutionModules.resolve(plan)

      assert provider_mod == ReqLlmNext.Providers.OpenAI
      assert wire_mod == ReqLlmNext.Wire.OpenAIResponses
      assert transport_mod == ReqLlmNext.Transports.HTTPStream
    end

    test "maps openai websocket plans to the websocket transport module" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")
      {:ok, plan} = OperationPlanner.plan(model, :text, "Hello", transport: :websocket)

      assert %{provider_mod: provider_mod, wire_mod: wire_mod, transport_mod: transport_mod} =
               ExecutionModules.resolve(plan)

      assert provider_mod == ReqLlmNext.Providers.OpenAI
      assert wire_mod == ReqLlmNext.Wire.OpenAIResponses
      assert transport_mod == ReqLlmNext.Transports.OpenAIResponsesWebSocket
    end

    test "maps anthropic plans to the current bridge modules" do
      {:ok, model} = LLMDB.model("anthropic:claude-haiku-4-5")
      {:ok, plan} = OperationPlanner.plan(model, :text, "Hello")

      assert %{provider_mod: provider_mod, wire_mod: wire_mod, transport_mod: transport_mod} =
               ExecutionModules.resolve(plan)

      assert provider_mod == ReqLlmNext.Providers.Anthropic
      assert wire_mod == ReqLlmNext.Wire.Anthropic
      assert transport_mod == ReqLlmNext.Transports.HTTPStream
    end
  end
end
