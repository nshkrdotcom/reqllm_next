defmodule ReqLlmNext.Wire.OpenAIResponses.WireEventTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.TestModels
  alias ReqLlmNext.Wire.OpenAIResponses

  describe "decode_wire_event/1" do
    test "returns :done for [DONE] payloads" do
      assert OpenAIResponses.decode_wire_event(%{data: "[DONE]"}) == [:done]
    end

    test "decodes JSON string payloads into raw event maps" do
      assert OpenAIResponses.decode_wire_event(%{
               data: ~s({"type":"response.output_text.delta","delta":"Hello"})
             }) == [%{"type" => "response.output_text.delta", "delta" => "Hello"}]
    end

    test "passes through pre-decoded map payloads" do
      payload = %{"type" => "response.output_text.delta", "delta" => "Text"}
      assert OpenAIResponses.decode_wire_event(%{data: payload}) == [payload]
    end

    test "returns decode_error tuples for invalid JSON" do
      assert [{:decode_error, _}] = OpenAIResponses.decode_wire_event(%{data: "not valid json"})
    end

    test "returns empty list for unhandled payload shapes" do
      assert OpenAIResponses.decode_wire_event(%{something: "else"}) == []
    end
  end

  describe "decode_sse_event/2" do
    test "delegates raw wire payloads through semantic normalization" do
      model = TestModels.openai_reasoning()

      assert ["Hello"] =
               OpenAIResponses.decode_sse_event(
                 %{data: ~s({"type":"response.output_text.delta","delta":"Hello"})},
                 model
               )
    end
  end
end
