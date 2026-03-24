defmodule ReqLlmNext.PublicAPI.ObjectGenerationTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.{Context, Response, StreamResponse}

  @person_schema [
    name: [type: :string, required: true],
    age: [type: :integer, required: true]
  ]

  describe "stream_object/4" do
    test "returns a StreamResponse with an object stream" do
      {:ok, resp} =
        ReqLlmNext.stream_object(
          "openai:gpt-4o-mini",
          "Generate a person",
          @person_schema,
          fixture: "person_object"
        )

      assert %StreamResponse{} = resp
      assert resp.model.id == "gpt-4o-mini"
    end

    test "produces valid JSON chunks" do
      {:ok, resp} =
        ReqLlmNext.stream_object(
          "openai:gpt-4o-mini",
          "Generate a person",
          @person_schema,
          fixture: "person_object"
        )

      text = StreamResponse.text(resp)
      {:ok, object} = Jason.decode(text)

      assert is_binary(object["name"])
      assert is_integer(object["age"])
    end

    test "accepts Context prompts" do
      context =
        ReqLlmNext.context([
          Context.user("Generate a software engineer profile")
        ])

      {:ok, resp} =
        ReqLlmNext.stream_object(
          "openai:gpt-4o-mini",
          context,
          @person_schema,
          fixture: "person_object"
        )

      assert %StreamResponse{} = resp
      assert is_map(StreamResponse.object(resp))
    end

    test "returns an error for an invalid model" do
      assert {:error, _} =
               ReqLlmNext.stream_object("openai:nonexistent", "Generate", @person_schema, [])
    end
  end

  describe "generate_object/4" do
    test "returns a Response with a parsed object" do
      {:ok, resp} =
        ReqLlmNext.generate_object(
          "openai:gpt-4o-mini",
          "Generate a software engineer profile",
          @person_schema,
          fixture: "person_object"
        )

      assert %Response{} = resp
      assert is_map(resp.object)
      assert is_binary(resp.object["name"])
      assert is_integer(resp.object["age"])
    end

    test "supports object generation for Anthropic models" do
      {:ok, resp} =
        ReqLlmNext.generate_object(
          "anthropic:claude-haiku-4-5",
          "Generate a software engineer profile",
          @person_schema,
          fixture: "object_streaming"
        )

      assert %Response{} = resp
      assert is_map(resp.object)
      assert is_binary(resp.object["name"])
      assert is_integer(resp.object["age"])
    end

    test "accepts Context prompts" do
      context =
        ReqLlmNext.context([
          Context.user("Generate a software engineer profile")
        ])

      {:ok, resp} =
        ReqLlmNext.generate_object(
          "openai:gpt-4o-mini",
          context,
          @person_schema,
          fixture: "person_object"
        )

      assert %Response{} = resp
      assert is_map(resp.object)
    end

    test "returns an error for an invalid model" do
      assert {:error, _} =
               ReqLlmNext.generate_object("openai:nonexistent", "Generate", @person_schema, [])
    end

    test "returns an error for an invalid schema" do
      assert {:error, {:invalid_schema, _}} =
               ReqLlmNext.generate_object(
                 "openai:gpt-4o-mini",
                 "Generate",
                 "not a valid schema",
                 []
               )
    end
  end

  describe "generate_object!/4" do
    test "returns a Response on success" do
      resp =
        ReqLlmNext.generate_object!(
          "openai:gpt-4o-mini",
          "Generate a software engineer profile",
          @person_schema,
          fixture: "person_object"
        )

      assert %Response{} = resp
      assert is_map(resp.object)
    end

    test "raises on model not found" do
      assert_raise ArgumentError, fn ->
        ReqLlmNext.generate_object!("openai:nonexistent", "Generate", @person_schema, [])
      end
    end
  end
end
