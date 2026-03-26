defmodule ReqLlmNext.SurfacePreparation.GoogleGenerateContentTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Error
  alias ReqLlmNext.ExecutionSurface
  alias ReqLlmNext.SurfacePreparation.GoogleGenerateContent
  alias ReqLlmNext.Tool

  defp surface(operation) do
    ExecutionSurface.new!(%{
      id: :"google_generate_content_#{operation}_http_sse",
      operation: operation,
      semantic_protocol: :google_generate_content,
      wire_format: :google_generate_content_sse_json,
      transport: :http_sse,
      features: %{streaming: true},
      fallback_ids: []
    })
  end

  test "rejects grounding on v1 requests" do
    assert {:error, %Error.Invalid.Parameter{}} =
             GoogleGenerateContent.validate(
               surface(:text),
               provider_options: [google_api_version: "v1", google_grounding: %{enable: true}]
             )
  end

  test "rejects tools on v1 requests" do
    tool =
      Tool.new!(
        name: "weather",
        description: "Get weather",
        parameter_schema: [location: [type: :string, required: true]],
        callback: fn _args -> {:ok, %{}} end
      )

    assert {:error, %Error.Invalid.Parameter{}} =
             GoogleGenerateContent.validate(
               surface(:text),
               provider_options: [google_api_version: "v1"],
               tools: [tool]
             )
  end

  test "rejects combined thinking budget and level" do
    assert {:error, %Error.Invalid.Parameter{}} =
             GoogleGenerateContent.validate(
               surface(:text),
               provider_options: [google_thinking_budget: 128, google_thinking_level: :high]
             )
  end

  test "rejects tools on object requests" do
    tool =
      Tool.new!(
        name: "weather",
        description: "Get weather",
        parameter_schema: [location: [type: :string, required: true]],
        callback: fn _args -> {:ok, %{}} end
      )

    assert {:error, %Error.Invalid.Parameter{}} =
             GoogleGenerateContent.validate(surface(:object), operation: :object, tools: [tool])
  end
end
