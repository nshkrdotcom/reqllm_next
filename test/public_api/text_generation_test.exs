defmodule ReqLlmNext.PublicAPI.TextGenerationTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.{Context, Error, Response, StreamResponse}

  describe "generate_text/3" do
    test "returns a Response using buffered fixture replay" do
      {:ok, result} =
        ReqLlmNext.generate_text("openai:gpt-4o-mini", "Hello!", fixture: "basic")

      assert %Response{} = result
      assert is_binary(Response.text(result))
      assert String.length(Response.text(result)) > 0
      assert result.model.id == "gpt-4o-mini"
    end

    test "accepts LLMDB.Model inputs through the public API" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")
      {:ok, result} = ReqLlmNext.generate_text(model, "Hello!", fixture: "basic")

      assert %Response{} = result
      assert result.model == model
    end

    test "rejects tuple model inputs through the public API" do
      assert {:error, {:invalid_model_spec, {:openai, "gpt-4o-mini"}}} =
               ReqLlmNext.generate_text({:openai, "gpt-4o-mini"}, "Hello!")
    end

    test "accepts Context prompts" do
      context =
        ReqLlmNext.context([
          Context.user("Hello!")
        ])

      {:ok, result} = ReqLlmNext.generate_text("openai:gpt-4o-mini", context, fixture: "basic")

      assert %Response{} = result
      assert is_binary(Response.text(result))
      assert %Context{} = result.context
    end
  end

  describe "generate_text!/3" do
    test "returns a Response on success" do
      result = ReqLlmNext.generate_text!("openai:gpt-4o-mini", "Hello!", fixture: "basic")

      assert %Response{} = result
      assert is_binary(Response.text(result))
    end

    test "raises on error" do
      assert_raise ArgumentError, fn ->
        ReqLlmNext.generate_text!("openai:nonexistent", "Hello!")
      end
    end
  end

  describe "stream_text/3" do
    test "returns a StreamResponse" do
      {:ok, resp} = ReqLlmNext.stream_text("openai:gpt-4o-mini", "Hello!", fixture: "basic")

      assert %StreamResponse{} = resp
      assert resp.model.id == "gpt-4o-mini"
    end

    test "produces text chunks" do
      {:ok, %StreamResponse{} = resp} =
        ReqLlmNext.stream_text("openai:gpt-4o-mini", "Hello!", fixture: "basic")

      chunks = Enum.to_list(resp.stream)

      assert chunks != []
      assert String.length(StreamResponse.text(%{resp | stream: chunks})) > 0
    end

    test "supports responses websocket transport through the public API" do
      {:ok, resp} =
        ReqLlmNext.stream_text("openai:gpt-4o-mini", "Hello!",
          fixture: "basic_websocket",
          transport: :websocket
        )

      assert %StreamResponse{} = resp
      assert resp.model.id == "gpt-4o-mini"
      assert String.length(StreamResponse.text(resp)) > 0
    end

    test "returns an error when websocket mode receives unsupported temperature" do
      assert {:error, %Error.Invalid.Parameter{} = error} =
               ReqLlmNext.stream_text("openai:gpt-4o-mini", "Hello!",
                 fixture: "basic_websocket",
                 transport: :websocket,
                 temperature: 0.7
               )

      assert Exception.message(error) =~ "temperature is not supported"
    end

    test "works with anthropic" do
      {:ok, resp} =
        ReqLlmNext.stream_text("anthropic:claude-haiku-4-5-20251001", "Hello!",
          fixture: "basic",
          max_tokens: 50
        )

      assert %StreamResponse{} = resp
      assert resp.model.provider == :anthropic
      assert String.length(StreamResponse.text(resp)) > 0
    end

    test "returns an error for an invalid model" do
      assert {:error, _} = ReqLlmNext.stream_text("openai:nonexistent", "Hello!", [])
    end
  end
end
