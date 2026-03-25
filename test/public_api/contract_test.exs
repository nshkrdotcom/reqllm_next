defmodule ReqLlmNext.PublicAPI.ContractTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Context

  @expected_exports [
    {:generate_text, 3},
    {:generate_text!, 3},
    {:stream_text, 3},
    {:stream_object, 4},
    {:generate_object, 4},
    {:generate_object!, 4},
    {:generate_image, 3},
    {:generate_image!, 3},
    {:transcribe, 3},
    {:transcribe!, 3},
    {:speak, 3},
    {:speak!, 3},
    {:embed, 3},
    {:embed!, 3},
    {:put_key, 2},
    {:get_key, 1},
    {:context, 1},
    {:provider, 1},
    {:model, 1},
    {:tool, 1},
    {:json_schema, 2},
    {:cosine_similarity, 2},
    {:embedding_models, 0}
  ]

  describe "hard public surface" do
    test "exports the top-level ReqLlmNext contract" do
      assert {:module, ReqLlmNext} = Code.ensure_loaded(ReqLlmNext)

      Enum.each(@expected_exports, fn {function, arity} ->
        assert function_exported?(ReqLlmNext, function, arity)
      end)
    end
  end

  describe "put_key/2 and get_key/1" do
    test "stores and retrieves atom keys from application config" do
      assert :ok = ReqLlmNext.put_key(:test_api_key, "test-value-123")
      assert ReqLlmNext.get_key(:test_api_key) == "test-value-123"
    end

    test "get_key/1 with string key reads from environment" do
      System.put_env("REQ_LLM_NEXT_TEST_KEY", "env-value")

      try do
        assert ReqLlmNext.get_key("REQ_LLM_NEXT_TEST_KEY") == "env-value"
      after
        System.delete_env("REQ_LLM_NEXT_TEST_KEY")
      end
    end

    test "returns nil for missing keys" do
      assert ReqLlmNext.get_key(:nonexistent_key_12345) == nil
    end

    test "raises for non-atom keys" do
      assert_raise ArgumentError, ~r/expects an atom key/, fn ->
        ReqLlmNext.put_key("string_key", "value")
      end
    end
  end

  describe "context/1" do
    test "creates context from a string prompt" do
      ctx = ReqLlmNext.context("Hello!")

      assert %Context{} = ctx
      assert length(ctx.messages) == 1
      assert hd(ctx.messages).role == :user
    end

    test "creates context from a message list" do
      messages = [
        Context.system("You are helpful"),
        Context.user("Hello!")
      ]

      ctx = ReqLlmNext.context(messages)

      assert length(ctx.messages) == 2
      assert Enum.at(ctx.messages, 0).role == :system
      assert Enum.at(ctx.messages, 1).role == :user
    end

    test "creates context from a single message" do
      msg = Context.user("Hello!")
      ctx = ReqLlmNext.context(msg)

      assert length(ctx.messages) == 1
      assert hd(ctx.messages).role == :user
    end
  end

  describe "provider/1" do
    test "returns known provider modules" do
      assert {:ok, ReqLlmNext.Providers.OpenAI} = ReqLlmNext.provider(:openai)
      assert {:ok, ReqLlmNext.Providers.Anthropic} = ReqLlmNext.provider(:anthropic)
    end

    test "returns an error for an unknown provider" do
      assert {:error, {:unknown_provider, :unknown_provider}} =
               ReqLlmNext.provider(:unknown_provider)
    end
  end

  describe "model/1" do
    test "resolves string model specs" do
      assert {:ok, model} = ReqLlmNext.model("openai:gpt-4o-mini")
      assert model.provider == :openai
      assert model.id == "gpt-4o-mini"
    end

    test "passes through LLMDB.Model structs" do
      {:ok, original} = LLMDB.model("openai:gpt-4o")
      assert {:ok, ^original} = ReqLlmNext.model(original)
    end

    test "accepts handcrafted LLMDB.Model structs" do
      handcrafted =
        LLMDB.Model.new!(%{
          id: "ollama:llama3-local",
          provider: :openai,
          name: "Local Llama 3",
          capabilities: %{chat: true},
          extra: %{
            wire: %{protocol: "openai_chat"}
          }
        })

      assert {:ok, ^handcrafted} = ReqLlmNext.model(handcrafted)
    end

    test "rejects tuple model specs" do
      assert {:error, {:invalid_model_spec, {:openai, "gpt-4o-mini", [temperature: 0.7]}}} =
               ReqLlmNext.model({:openai, "gpt-4o-mini", temperature: 0.7})
    end

    test "rejects provider keyword tuples" do
      assert {:error, {:invalid_model_spec, {:openai, [id: "gpt-4o-mini"]}}} =
               ReqLlmNext.model({:openai, id: "gpt-4o-mini"})
    end

    test "returns an error for an invalid spec" do
      assert {:error, _} = ReqLlmNext.model(:invalid)
    end
  end

  describe "tool/1" do
    test "creates a Tool struct from options" do
      tool =
        ReqLlmNext.tool(
          name: "get_weather",
          description: "Get weather for location",
          callback: fn _args -> {:ok, "sunny"} end
        )

      assert %ReqLlmNext.Tool{} = tool
      assert tool.name == "get_weather"
      assert tool.description == "Get weather for location"
    end

    test "creates a Tool with parameter schema" do
      tool =
        ReqLlmNext.tool(
          name: "add",
          description: "Add numbers",
          parameter_schema: [
            a: [type: :integer, required: true],
            b: [type: :integer, required: true]
          ],
          callback: fn args -> {:ok, args["a"] + args["b"]} end
        )

      assert tool.name == "add"
      assert tool.parameter_schema != nil
    end

    test "raises when required options are missing" do
      assert_raise ArgumentError, fn ->
        ReqLlmNext.tool(name: "test")
      end
    end
  end

  describe "json_schema/2" do
    test "converts a NimbleOptions schema to JSON Schema" do
      nimble = [
        name: [type: :string, required: true, doc: "Person name"],
        age: [type: :integer]
      ]

      result = ReqLlmNext.json_schema(nimble, name: "Person")

      assert result["title"] == "Person"
      assert result["type"] == "object"
      assert result["properties"]["name"]["type"] == "string"
      assert result["properties"]["age"]["type"] == "integer"
      assert "name" in result["required"]
    end

    test "works without options" do
      nimble = [value: [type: :string]]
      result = ReqLlmNext.json_schema(nimble)

      assert result["type"] == "object"
      assert result["properties"]["value"]["type"] == "string"
    end
  end
end
