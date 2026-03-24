defmodule ReqLlmNext.FixturesTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Fixtures
  alias ReqLlmNext.TestModels

  describe "mode/0" do
    test "returns :replay by default" do
      assert Fixtures.mode() == :replay
    end
  end

  describe "path/2" do
    test "generates path for openai model" do
      model = TestModels.openai(%{id: "gpt-4o-mini"})
      path = Fixtures.path(model, "basic")

      assert path =~ "test/fixtures/openai/gpt_4o_mini/basic.json"
    end

    test "generates path for anthropic model" do
      model = TestModels.anthropic(%{id: "claude-sonnet-4-20250514"})
      path = Fixtures.path(model, "basic")

      assert path =~ "test/fixtures/anthropic/claude_sonnet_4_20250514/basic.json"
    end

    test "sanitizes fixture name with special chars" do
      model = TestModels.openai(%{id: "gpt-4o"})
      path = Fixtures.path(model, "test/with spaces!")

      assert path =~ "with_spaces.json"
    end
  end

  describe "record_status/2" do
    test "returns nil when recorder is nil" do
      assert Fixtures.record_status(nil, 200) == nil
    end

    test "updates recorder with status" do
      recorder = %{status: nil}
      result = Fixtures.record_status(recorder, 200)
      assert result.status == 200
    end
  end

  describe "record_headers/2" do
    test "returns nil when recorder is nil" do
      assert Fixtures.record_headers(nil, [{"content-type", "text/event-stream"}]) == nil
    end

    test "updates recorder with normalized headers" do
      recorder = %{headers: %{}}
      headers = [{"Content-Type", "text/event-stream"}, {"X-Request-Id", "abc123"}]
      result = Fixtures.record_headers(recorder, headers)

      assert result.headers == %{
               "content-type" => "text/event-stream",
               "x-request-id" => "abc123"
             }
    end
  end

  describe "record_chunk/2" do
    test "returns nil when recorder is nil" do
      assert Fixtures.record_chunk(nil, "data: test\n\n") == nil
    end

    test "appends base64-encoded chunk to recorder" do
      recorder = %{chunks: []}
      result = Fixtures.record_chunk(recorder, "data: hello\n\n")

      assert length(result.chunks) == 1
      assert Base.decode64!(hd(result.chunks)) == "data: hello\n\n"
    end

    test "prepends new chunks (reversed on save)" do
      recorder = %{chunks: ["Zmlyc3Q="]}
      result = Fixtures.record_chunk(recorder, "second")

      assert length(result.chunks) == 2
      assert hd(result.chunks) == Base.encode64("second")
    end
  end

  describe "save_fixture/1" do
    test "returns :ok when recorder is nil" do
      assert Fixtures.save_fixture(nil) == :ok
    end
  end

  describe "start_recorder/5" do
    test "creates recorder struct" do
      model = TestModels.openai(%{id: "gpt-4o-mini"})
      finch_request = Finch.build(:post, "https://api.openai.com/v1/chat/completions", [], "{}")
      prompt = "Hello!"

      recorder = Fixtures.start_recorder(model, "test", prompt, finch_request)

      assert recorder.model == model
      assert recorder.fixture_name == "test"
      assert recorder.prompt == prompt
      assert recorder.status == nil
      assert recorder.headers == %{}
      assert recorder.chunks == []
      assert is_binary(recorder.captured_at)
      assert is_map(recorder.request)
      assert recorder.execution == %{}
    end

    test "extracts request info with redacted auth" do
      model = TestModels.openai(%{id: "gpt-4o-mini"})
      headers = [{"Authorization", "Bearer sk-secret"}, {"Content-Type", "application/json"}]
      body = ~s({"model":"gpt-4o-mini"})

      finch_request =
        Finch.build(:post, "https://api.openai.com/v1/chat/completions", headers, body)

      recorder = Fixtures.start_recorder(model, "test", "Hello!", finch_request)

      assert recorder.request["method"] == "POST"
      assert recorder.request["url"] =~ "api.openai.com"
      assert recorder.request["headers"]["authorization"] == "[REDACTED]"
      assert recorder.request["headers"]["content-type"] == "application/json"
      assert recorder.request["body"]["canonical_json"]["model"] == "gpt-4o-mini"
    end

    test "normalizes websocket request maps with redacted auth" do
      model = TestModels.openai(%{id: "gpt-4o-mini"})

      request = %{
        method: "WEBSOCKET",
        url: "wss://api.openai.com/v1/responses",
        transport: "websocket",
        headers: [
          {"Authorization", "Bearer sk-secret"},
          {"OpenAI-Beta", "responses=v1"}
        ],
        body: %{
          type: "response.create",
          model: "gpt-4o-mini"
        }
      }

      recorder =
        Fixtures.start_recorder(model, "websocket", "Hello!", request, %{
          surface_id: :openai_responses_text_websocket,
          semantic_protocol: :openai_responses,
          wire_format: :openai_responses_ws_json,
          transport: :websocket
        })

      assert recorder.request["method"] == "WEBSOCKET"
      assert recorder.request["transport"] == "websocket"
      assert recorder.request["url"] == "wss://api.openai.com/v1/responses"
      assert recorder.request["headers"]["authorization"] == "[REDACTED]"
      assert recorder.request["headers"]["openai-beta"] == "responses=v1"
      assert recorder.execution["surface_id"] == "openai_responses_text_websocket"
      assert recorder.execution["semantic_protocol"] == "openai_responses"
      assert recorder.execution["wire_format"] == "openai_responses_ws_json"
      assert recorder.execution["transport"] == "websocket"

      assert (recorder.request["body"]["canonical_json"]["type"] ||
                recorder.request["body"]["canonical_json"][:type]) == "response.create"

      assert (recorder.request["body"]["canonical_json"]["model"] ||
                recorder.request["body"]["canonical_json"][:model]) == "gpt-4o-mini"
    end
  end

  describe "maybe_replay_stream/3" do
    test "returns :no_fixture when no fixture option" do
      model = TestModels.openai(%{id: "gpt-4o"})
      assert Fixtures.maybe_replay_stream(model, "Hello", []) == :no_fixture
    end

    test "returns :no_fixture when fixture option is nil" do
      model = TestModels.openai(%{id: "gpt-4o"})
      assert Fixtures.maybe_replay_stream(model, "Hello", fixture: nil) == :no_fixture
    end

    test "returns stream for existing fixture" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")
      {:ok, stream} = Fixtures.maybe_replay_stream(model, "Hello", fixture: "basic")

      chunks = Enum.to_list(stream)
      assert is_list(chunks)
      refute Enum.empty?(chunks)
    end
  end

  describe "save_fixture integration" do
    test "saves and can replay fixture" do
      model = TestModels.openai()
      fixture_path = Fixtures.path(model, "integration_test")

      File.rm(fixture_path)

      recorder = %{
        model: model,
        fixture_name: "integration_test",
        prompt: "Test prompt",
        captured_at: DateTime.utc_now() |> DateTime.to_iso8601(),
        request: %{"method" => "POST", "url" => "https://example.com"},
        execution: %{},
        status: 200,
        headers: %{"content-type" => "text/event-stream"},
        chunks: [Base.encode64(~s(data: {"choices":[{"delta":{"content":"Hi"}}]}\n\n))]
      }

      assert Fixtures.save_fixture(recorder) == :ok
      assert File.exists?(fixture_path)

      File.rm!(fixture_path)
      File.rmdir(Path.dirname(fixture_path))
    end

    test "saves and replays websocket fixtures using recorded transport" do
      model = TestModels.openai(%{id: "ws-test-model"})
      fixture_path = Fixtures.path(model, "integration_websocket")

      File.rm(fixture_path)

      recorder = %{
        model: model,
        fixture_name: "integration_websocket",
        prompt: "Test prompt",
        captured_at: DateTime.utc_now() |> DateTime.to_iso8601(),
        request: %{
          "method" => "WEBSOCKET",
          "url" => "wss://api.openai.com/v1/responses",
          "transport" => "websocket",
          "headers" => %{"authorization" => "[REDACTED]"},
          "body" => %{
            "canonical_json" => %{"type" => "response.create", "model" => "ws-test-model"},
            "b64" => Base.encode64(~s({"type":"response.create","model":"ws-test-model"}))
          }
        },
        execution: %{
          "surface_id" => "openai_responses_text_websocket",
          "semantic_protocol" => "openai_responses",
          "wire_format" => "openai_responses_ws_json",
          "transport" => "websocket"
        },
        status: 101,
        headers: %{"upgrade" => "websocket"},
        chunks: [
          Base.encode64(~s({"type":"response.output_text.delta","delta":"Hi"})),
          Base.encode64(~s({"type":"response.completed","response":{"id":"resp_123"}}))
        ]
      }

      assert Fixtures.save_fixture(recorder) == :ok
      assert File.exists?(fixture_path)

      assert {:ok, stream} =
               Fixtures.maybe_replay_stream(model, "Test prompt",
                 fixture: "integration_websocket"
               )

      chunks = Enum.to_list(stream)

      assert "Hi" in chunks

      assert Enum.any?(chunks, fn
               {:meta, %{terminal?: true, response_id: "resp_123", finish_reason: :stop}} -> true
               _ -> false
             end)

      fixture = fixture_path |> File.read!() |> Jason.decode!()
      assert fixture["execution"]["wire_format"] == "openai_responses_ws_json"
      assert fixture["execution"]["semantic_protocol"] == "openai_responses"

      File.rm!(fixture_path)
      File.rmdir(Path.dirname(fixture_path))
    end
  end
end
