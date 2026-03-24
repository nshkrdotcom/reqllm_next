defmodule ReqLlmNext.Scenarios.ObjectAndImageTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Scenarios
  alias ReqLlmNext.TestModels
  import ReqLlmNext.ScenarioTestHelpers

  describe "ObjectStreaming" do
    test "reports metadata and applicability" do
      assert_scenario_metadata(Scenarios.ObjectStreaming, :object_streaming, "Object Streaming")

      assert Scenarios.ObjectStreaming.applies?(
               TestModels.openai(%{
                 capabilities: %{
                    chat: true,
                    json: %{native: true, schema: true, strict: true},
                    streaming: %{text: true, tool_calls: true}
                  }
                })
              )

      assert Scenarios.ObjectStreaming.applies?(
               TestModels.anthropic(%{
                 capabilities: %{
                    chat: true,
                    json: %{native: true, schema: false, strict: false}
                  }
                })
              )

      refute Scenarios.ObjectStreaming.applies?(TestModels.openai_embedding())

      refute Scenarios.ObjectStreaming.applies?(
               TestModels.openai(%{
                 capabilities: %{
                   chat: true,
                    json: %{native: true, schema: true, strict: true},
                    streaming: %{text: false, tool_calls: false}
                  }
                })
              )
    end

    test "validates streamed object shapes" do
      assert validate_object_response("not a map") == %{
               status: :error,
               error: :invalid_object_type
             }

      assert validate_object_response(%{"age" => 28}) == %{status: :error, error: :missing_name}

      assert validate_object_response(%{"name" => "Alice"}) == %{
               status: :error,
               error: :missing_age
             }

      assert validate_object_response(%{"name" => "", "age" => 28}) == %{
               status: :error,
               error: :invalid_name
             }

      assert validate_object_response(%{"name" => "Alice", "age" => 28}) == :ok
    end

    test "runs successfully with fixture replay" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")

      assert_ok_result(
        Scenarios.ObjectStreaming.run("openai:gpt-4o-mini", model, []),
        "stream_object"
      )
    end
  end

  describe "ImageInput" do
    test "reports metadata and applicability" do
      assert_scenario_metadata(Scenarios.ImageInput, :image_input, "Image Input")
      assert Scenarios.ImageInput.applies?(TestModels.vision())
      refute Scenarios.ImageInput.applies?(TestModels.openai_embedding())
    end

    test "validates image descriptions" do
      assert validate_image_description("") == %{status: :error, error: :empty_response}
      assert validate_image_description("The image is red.") == :ok
      assert validate_image_description("Bright crimson red square.") == :ok

      assert validate_image_description("This is a cat.") == %{
               status: :error,
               error: {:unexpected_description, "This is a cat."}
             }
    end

    test "runs successfully with fixture replay" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")

      assert_ok_result(
        Scenarios.ImageInput.run("openai:gpt-4o-mini", model, []),
        "image_describe"
      )
    end
  end
end
