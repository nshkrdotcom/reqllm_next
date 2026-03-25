defmodule ReqLlmNext.SurfacePreparation.AnthropicMessagesTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.ExecutionSurface
  alias ReqLlmNext.SurfacePreparation.AnthropicMessages

  defp surface do
    ExecutionSurface.new!(%{
      id: :anthropic_messages,
      operation: :text,
      semantic_protocol: :anthropic_messages,
      wire_format: :anthropic_messages_sse_json,
      transport: :http_sse
    })
  end

  test "normalizes compact shorthand into a documented compaction edit" do
    assert {:ok, prepared} =
             AnthropicMessages.prepare(surface(), "hello", context_management: %{compact: true})

    assert prepared[:context_management] == %{edits: [%{type: "compact_20260112"}]}
  end

  test "normalizes compact config maps into a compaction edit" do
    assert {:ok, prepared} =
             AnthropicMessages.prepare(surface(), "hello",
               context_management: %{compact: %{trigger: %{type: "input_tokens", value: 100_000}}}
             )

    assert prepared[:context_management] == %{
             edits: [
               %{type: "compact_20260112", trigger: %{type: "input_tokens", value: 100_000}}
             ]
           }
  end

  test "validates documented context management edit order" do
    assert {:error, error} =
             AnthropicMessages.validate(surface(),
               thinking: %{type: "adaptive"},
               context_management: %{
                 edits: [
                   %{type: "clear_tool_uses_20250919"},
                   %{type: "clear_thinking_20251015"}
                 ]
               }
             )

    assert Exception.message(error) =~ "clear_thinking_20251015 before clear_tool_uses_20250919"
  end

  test "requires Anthropic thinking when clear_thinking edit is used" do
    assert {:error, error} =
             AnthropicMessages.validate(surface(),
               context_management: %{edits: [%{type: "clear_thinking_20251015"}]}
             )

    assert Exception.message(error) =~ "clear_thinking_20251015 requires Anthropic thinking"
  end

  test "accepts clear_thinking edit when Anthropic thinking is enabled" do
    assert :ok =
             AnthropicMessages.validate(surface(),
               thinking: %{type: "adaptive"},
               context_management: %{edits: [%{type: "clear_thinking_20251015"}]}
             )
  end

  test "accepts clear_thinking edit when reasoning_effort is set" do
    assert :ok =
             AnthropicMessages.validate(surface(),
               reasoning_effort: :medium,
               context_management: %{edits: [%{type: "clear_thinking_20251015"}]}
             )
  end

  test "rejects unknown context management edit types" do
    assert {:error, error} =
             AnthropicMessages.validate(surface(),
               context_management: %{edits: [%{type: "unknown_edit"}]}
             )

    assert Exception.message(error) =~ "context_management.edits must use Anthropic edit types"
  end
end
