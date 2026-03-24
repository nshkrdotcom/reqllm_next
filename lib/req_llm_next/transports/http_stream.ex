defmodule ReqLlmNext.Transports.HTTPStream do
  @moduledoc false

  alias ReqLlmNext.Executor.StreamState
  alias ReqLlmNext.Fixtures
  alias ReqLlmNext.Wire.Streaming

  @default_stream_timeout Application.compile_env(:req_llm_next, :stream_timeout, 30_000)

  @spec stream(
          module(),
          module(),
          module(),
          LLMDB.Model.t(),
          String.t() | ReqLlmNext.Context.t(),
          keyword()
        ) ::
          {:ok, Enumerable.t()} | {:error, term()}
  def stream(provider_mod, protocol_mod, wire_mod, model, prompt, opts) do
    with {:ok, finch_request} <-
           Streaming.build_request(provider_mod, wire_mod, model, prompt, opts) do
      recorder = maybe_start_recorder(model, prompt, finch_request, opts)
      receive_timeout = Keyword.get(opts, :receive_timeout, @default_stream_timeout)

      stream =
        Stream.resource(
          fn ->
            start_finch_stream(
              finch_request,
              recorder,
              model,
              wire_mod,
              protocol_mod,
              receive_timeout
            )
          end,
          &next_chunk/1,
          &cleanup/1
        )

      {:ok, stream}
    end
  end

  defp maybe_start_recorder(model, prompt, finch_request, opts) do
    case {Fixtures.mode(), Keyword.get(opts, :fixture)} do
      {:record, fixture_name} when is_binary(fixture_name) ->
        Fixtures.start_recorder(
          model,
          fixture_name,
          prompt,
          finch_request,
          execution_metadata(opts)
        )

      _ ->
        nil
    end
  end

  defp start_finch_stream(finch_request, recorder, model, wire_mod, protocol_mod, receive_timeout) do
    parent = self()
    ref = make_ref()

    task =
      Task.async(fn ->
        Finch.stream(finch_request, ReqLlmNext.Finch, nil, fn
          {:status, status}, _acc ->
            send(parent, {ref, :status, status})
            nil

          {:headers, headers}, _acc ->
            send(parent, {ref, :headers, headers})
            nil

          {:data, data}, _acc ->
            send(parent, {ref, :data, data})
            nil
        end)

        send(parent, {ref, :done})
      end)

    %{
      ref: ref,
      task: task,
      stream_state: StreamState.new(recorder, model, wire_mod, protocol_mod),
      receive_timeout: receive_timeout
    }
  end

  defp next_chunk(%{ref: ref, stream_state: stream_state, receive_timeout: timeout} = state) do
    receive do
      {^ref, :status, status} ->
        handle_stream_result(StreamState.handle_message({:status, status}, stream_state), state)

      {^ref, :headers, headers} ->
        handle_stream_result(StreamState.handle_message({:headers, headers}, stream_state), state)

      {^ref, :data, data} ->
        handle_stream_result(StreamState.handle_message({:data, data}, stream_state), state)

      {^ref, :done} ->
        handle_stream_result(StreamState.handle_message(:done, stream_state), state)
    after
      timeout ->
        new_stream_state = StreamState.handle_timeout(stream_state)
        {:halt, %{state | stream_state: new_stream_state}}
    end
  end

  defp handle_stream_result({:cont, [], new_stream_state}, state) do
    next_chunk(%{state | stream_state: new_stream_state})
  end

  defp handle_stream_result({:cont, chunks, new_stream_state}, state) do
    {chunks, %{state | stream_state: new_stream_state}}
  end

  defp handle_stream_result({:halt, new_stream_state}, state) do
    {:halt, %{state | stream_state: new_stream_state}}
  end

  defp cleanup(%{task: task}) do
    Task.shutdown(task, :brutal_kill)
    :ok
  end

  defp execution_metadata(opts) do
    %{
      surface_id: Keyword.get(opts, :_execution_surface_id),
      semantic_protocol: Keyword.get(opts, :_execution_semantic_protocol),
      wire_format: Keyword.get(opts, :_execution_wire_format),
      transport: Keyword.get(opts, :_execution_transport)
    }
  end
end
