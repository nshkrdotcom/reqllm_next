defmodule ReqLlmNext.Wire.CerebrasChatTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.TestModels
  alias ReqLlmNext.Tool
  alias ReqLlmNext.Wire.CerebrasChat

  test "adds strict to tool schemas for strict-tool models" do
    tool =
      Tool.new!(
        name: "lookup",
        description: "Lookup data",
        parameter_schema: [location: [type: :string, required: true]],
        callback: fn _args -> {:ok, "done"} end
      )

    body =
      CerebrasChat.encode_body(
        TestModels.cerebras(%{
          capabilities: %{chat: true, tools: %{enabled: true, strict: true}}
        }),
        "Explain the result",
        tools: [tool]
      )

    assert [%{"function" => %{"strict" => true}}] = body.tools
  end

  test "strips unsupported schema constraints for non-strict models" do
    tool =
      Tool.new!(
        name: "lookup",
        description: "Lookup data",
        parameter_schema: %{
          "type" => "object",
          "properties" => %{
            "age" => %{
              "type" => "integer",
              "minimum" => 1,
              "maximum" => 10
            }
          },
          "required" => ["age"]
        },
        callback: fn _args -> {:ok, "done"} end
      )

    body =
      CerebrasChat.encode_body(
        TestModels.cerebras(%{
          capabilities: %{chat: true, tools: %{enabled: true, strict: false}}
        }),
        "Explain the result",
        tools: [tool]
      )

    [%{"function" => %{"parameters" => parameters}}] = body.tools
    property = parameters["properties"]["age"]
    refute Map.has_key?(property, "minimum")
    refute Map.has_key?(property, "maximum")
  end
end
