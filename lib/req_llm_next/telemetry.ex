defmodule ReqLlmNext.Telemetry do
  @moduledoc """
  Stable telemetry boundary for ReqLlmNext runtime and verification flows.
  """

  alias ReqLlmNext.{ExecutionPlan, Response, StreamResponse}
  alias ReqLlmNext.Realtime.Event, as: RealtimeEvent
  alias ReqLlmNext.Speech.Result, as: SpeechResult
  alias ReqLlmNext.Transcription.Result, as: TranscriptionResult

  @event_prefix [:req_llm_next]
  @sensitive_keys ~w(
    prompt
    input
    text
    body
    payload
    messages
    content
    reasoning
    reasoning_content
    transcript
    audio
    data
    raw_json
    response_body
  )a

  @type event_name :: [atom()]

  @type metadata :: map()

  @spec span_request(metadata(), (-> term())) :: term()
  def span_request(metadata, fun) when is_map(metadata) and is_function(fun, 0) do
    span([:request], metadata, fun, &request_result_measurements/1, &request_result_metadata/1)
  end

  @spec span_provider_request(metadata(), (-> term())) :: term()
  def span_provider_request(metadata, fun) when is_map(metadata) and is_function(fun, 0) do
    span(
      [:provider, :request],
      metadata,
      fun,
      &provider_result_measurements/1,
      &provider_result_metadata/1
    )
  end

  @spec emit_plan_resolved(ExecutionPlan.t()) :: :ok
  def emit_plan_resolved(%ExecutionPlan{} = plan) do
    metadata =
      plan
      |> request_metadata_from_plan()
      |> Map.merge(%{
        timeout_class: plan.timeout_class,
        timeout_ms: plan.timeout_ms,
        fallback_surface_count: length(plan.fallback_surfaces)
      })

    :telemetry.execute(
      @event_prefix ++ [:plan, :resolved],
      %{fallback_surface_count: length(plan.fallback_surfaces)},
      sanitize_metadata(metadata)
    )
  end

  @spec emit_execution_stack(ExecutionPlan.t(), map()) :: :ok
  def emit_execution_stack(%ExecutionPlan{} = plan, resolution) when is_map(resolution) do
    metadata =
      request_metadata_from_plan(plan)
      |> Map.merge(%{
        provider_module: inspect(Map.get(resolution, :provider_mod)),
        session_runtime_module: inspect(Map.get(resolution, :session_runtime_mod)),
        protocol_module: inspect(Map.get(resolution, :protocol_mod)),
        wire_module: inspect(Map.get(resolution, :wire_mod)),
        transport_module: inspect(Map.get(resolution, :transport_mod))
      })

    :telemetry.execute(
      @event_prefix ++ [:execution, :stack],
      %{},
      sanitize_metadata(metadata)
    )
  end

  @spec emit_fixture(:replay | :record, metadata(), map()) :: :ok
  def emit_fixture(action, metadata, measurements \\ %{})
      when action in [:replay, :record] and is_map(metadata) and is_map(measurements) do
    :telemetry.execute(
      @event_prefix ++ [:fixture, action],
      measurements,
      sanitize_metadata(metadata)
    )
  end

  @spec emit_compat_scenario(:start | :stop, metadata(), map()) :: :ok
  def emit_compat_scenario(stage, metadata, measurements \\ %{})
      when stage in [:start, :stop] and is_map(metadata) and is_map(measurements) do
    :telemetry.execute(
      @event_prefix ++ [:compat, :scenario, stage],
      measurements,
      sanitize_metadata(metadata)
    )
  end

  @spec instrument_stream(Enumerable.t(), metadata()) :: Enumerable.t()
  def instrument_stream(stream, metadata) when is_map(metadata) do
    Stream.transform(
      stream,
      fn ->
        start_metadata = sanitize_metadata(metadata)
        :telemetry.execute(@event_prefix ++ [:stream, :start], %{}, start_metadata)

        %{
          bytes: 0,
          chunk_count: 0,
          event_count: 0,
          finish_reason: nil,
          metadata: start_metadata,
          start_time: System.monotonic_time()
        }
      end,
      fn item, state ->
        next_state = update_stream_state(state, item)
        emit_stream_chunk(next_state.metadata, item, next_state)
        {[item], next_state}
      end,
      fn state ->
        :telemetry.execute(
          @event_prefix ++ [:stream, :stop],
          %{
            duration: System.monotonic_time() - state.start_time,
            bytes_out: state.bytes,
            chunk_count: state.chunk_count,
            event_count: state.event_count
          },
          maybe_put(state.metadata, :finish_reason, state.finish_reason)
        )
      end
    )
  end

  @spec request_metadata(term(), atom(), keyword()) :: metadata()
  def request_metadata(model_spec, operation, opts \\ [])
      when is_atom(operation) and is_list(opts) do
    %{
      model_spec: safe_model_spec(model_spec),
      operation: operation,
      requested_stream?: Keyword.get(opts, :_stream?, false) || Keyword.get(opts, :stream, false),
      requested_transport: Keyword.get(opts, :transport),
      requested_structured?:
        Keyword.has_key?(opts, :schema) or Keyword.has_key?(opts, :json_schema),
      requested_tools?: Keyword.has_key?(opts, :tools),
      fixture_mode: ReqLlmNext.Fixtures.mode()
    }
  end

  @spec request_metadata_from_plan(ExecutionPlan.t()) :: metadata()
  def request_metadata_from_plan(%ExecutionPlan{} = plan) do
    %{
      provider: plan.provider,
      family: plan.model.family,
      model_id: plan.model.model_id,
      operation: plan.mode.operation,
      surface_id: plan.surface.id,
      semantic_protocol: plan.semantic_protocol,
      wire_format: plan.wire_format,
      transport: plan.transport,
      stream?: plan.mode.stream?,
      tools?: plan.mode.tools?,
      structured?: plan.mode.structured_output?,
      session_strategy: Map.get(plan.session_strategy, :mode, :none),
      session_runtime: plan.session_runtime
    }
  end

  @spec provider_request_metadata(atom(), LLMDB.Model.t() | nil, keyword(), map()) :: metadata()
  def provider_request_metadata(provider, model, opts, extra \\ %{})
      when is_atom(provider) and is_list(opts) and is_map(extra) do
    base =
      %{
        provider: provider,
        model_id: model_id(model),
        operation: Keyword.get(opts, :operation),
        surface_id: Keyword.get(opts, :_execution_surface_id),
        semantic_protocol: Keyword.get(opts, :_execution_semantic_protocol),
        wire_format: Keyword.get(opts, :_execution_wire_format),
        transport: Keyword.get(opts, :_execution_transport),
        fixture_mode: ReqLlmNext.Fixtures.mode()
      }

    base
    |> Map.merge(extra)
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  @spec fixture_metadata(LLMDB.Model.t(), String.t(), map()) :: metadata()
  def fixture_metadata(%LLMDB.Model{} = model, fixture_name, extra \\ %{})
      when is_binary(fixture_name) and is_map(extra) do
    %{
      provider: model.provider,
      model_id: model.id,
      fixture: fixture_name
    }
    |> Map.merge(extra)
  end

  defp span(event_name, metadata, fun, measurement_fun, metadata_fun) do
    start_time = System.monotonic_time()
    start_metadata = sanitize_metadata(metadata)
    :telemetry.execute(@event_prefix ++ event_name ++ [:start], %{}, start_metadata)

    try do
      result = fun.()

      :telemetry.execute(
        @event_prefix ++ event_name ++ [:stop],
        Map.put(measurement_fun.(result), :duration, System.monotonic_time() - start_time),
        sanitize_metadata(Map.merge(start_metadata, metadata_fun.(result)))
      )

      result
    rescue
      error ->
        stacktrace = __STACKTRACE__

        :telemetry.execute(
          @event_prefix ++ event_name ++ [:exception],
          %{duration: System.monotonic_time() - start_time},
          sanitize_metadata(Map.merge(start_metadata, exception_metadata(error, stacktrace)))
        )

        reraise error, stacktrace
    catch
      kind, reason ->
        stacktrace = __STACKTRACE__

        :telemetry.execute(
          @event_prefix ++ event_name ++ [:exception],
          %{duration: System.monotonic_time() - start_time},
          sanitize_metadata(
            Map.merge(start_metadata, %{throw_kind: kind, throw_reason: inspect(reason)})
          )
        )

        :erlang.raise(kind, reason, stacktrace)
    end
  end

  defp request_result_measurements({:ok, result}), do: request_result_measurements(result)
  defp request_result_measurements({:error, _error}), do: %{}
  defp request_result_measurements(%Response{} = response), do: usage_measurements(response.usage)
  defp request_result_measurements(%StreamResponse{}), do: %{}
  defp request_result_measurements(%TranscriptionResult{}), do: %{}
  defp request_result_measurements(%SpeechResult{}), do: %{}

  defp request_result_measurements(embeddings) when is_list(embeddings),
    do: %{embedding_count: length(embeddings)}

  defp request_result_measurements(_result), do: %{}

  defp request_result_metadata({:ok, result}), do: request_result_metadata(result)

  defp request_result_metadata({:error, error}) do
    %{request_status: :error}
    |> merge_error_metadata(error)
  end

  defp request_result_metadata(%Response{} = response) do
    %{
      request_status: if(Response.ok?(response), do: :ok, else: :error),
      finish_reason: response.finish_reason,
      stream?: response.stream?
    }
    |> merge_error_metadata(response.error)
  end

  defp request_result_metadata(%StreamResponse{}), do: %{request_status: :ok, stream?: true}
  defp request_result_metadata(%TranscriptionResult{}), do: %{request_status: :ok}
  defp request_result_metadata(%SpeechResult{}), do: %{request_status: :ok}
  defp request_result_metadata(result) when is_list(result), do: %{request_status: :ok}
  defp request_result_metadata(_result), do: %{}

  defp provider_result_measurements({:ok, result}), do: provider_result_measurements(result)
  defp provider_result_measurements({:error, _error}), do: %{}

  defp provider_result_measurements(%Finch.Response{body: body}) when is_binary(body) do
    %{bytes_in: byte_size(body)}
  end

  defp provider_result_measurements(%Response{} = response),
    do: usage_measurements(response.usage)

  defp provider_result_measurements(%TranscriptionResult{}), do: %{}
  defp provider_result_measurements(%SpeechResult{}), do: %{}
  defp provider_result_measurements(_result), do: %{}

  defp provider_result_metadata({:ok, result}), do: provider_result_metadata(result)

  defp provider_result_metadata({:error, error}) do
    %{provider_request_status: :error}
    |> merge_error_metadata(error)
  end

  defp provider_result_metadata(%Finch.Response{status: status}) do
    %{provider_request_status: :ok, http_status: status}
  end

  defp provider_result_metadata(%Response{} = response) do
    %{provider_request_status: if(Response.ok?(response), do: :ok, else: :error)}
    |> maybe_put(:finish_reason, response.finish_reason)
    |> merge_error_metadata(response.error)
  end

  defp provider_result_metadata(%TranscriptionResult{}), do: %{provider_request_status: :ok}
  defp provider_result_metadata(%SpeechResult{}), do: %{provider_request_status: :ok}
  defp provider_result_metadata(_result), do: %{provider_request_status: :ok}

  defp usage_measurements(usage) when is_map(usage) do
    %{}
    |> maybe_put_measurement(:input_tokens, get_usage_value(usage, :input_tokens))
    |> maybe_put_measurement(:output_tokens, get_usage_value(usage, :output_tokens))
    |> maybe_put_measurement(:total_tokens, get_usage_value(usage, :total_tokens))
    |> maybe_put_measurement(:reasoning_tokens, get_usage_value(usage, :reasoning_tokens))
    |> maybe_put_measurement(:cache_read_tokens, get_usage_value(usage, :cache_read_tokens))
  end

  defp usage_measurements(_usage), do: %{}

  defp get_usage_value(usage, key) do
    usage[key] ||
      usage[Atom.to_string(key)] ||
      case key do
        :reasoning_tokens ->
          get_in(usage, [:completion_tokens_details, :reasoning_tokens]) ||
            get_in(usage, ["completion_tokens_details", "reasoning_tokens"])

        _ ->
          nil
      end
  end

  defp emit_stream_chunk(metadata, item, state) do
    measurements = %{
      bytes_out: chunk_bytes(item),
      chunk_count: state.chunk_count,
      event_count: state.event_count
    }

    chunk_metadata =
      metadata
      |> Map.put(:event_type, classify_stream_item(item))
      |> maybe_put(:finish_reason, finish_reason_from_item(item))

    :telemetry.execute(@event_prefix ++ [:stream, :chunk], measurements, chunk_metadata)

    if match?({:error, _}, item) or match?(%RealtimeEvent{type: :error}, item) do
      :telemetry.execute(
        @event_prefix ++ [:stream, :exception],
        %{},
        sanitize_metadata(Map.merge(chunk_metadata, stream_error_metadata(item)))
      )
    end
  end

  defp update_stream_state(state, item) do
    %{
      state
      | bytes: state.bytes + chunk_bytes(item),
        chunk_count: state.chunk_count + 1,
        event_count: state.event_count + stream_event_count(item),
        finish_reason: finish_reason_from_item(item) || state.finish_reason
    }
  end

  defp classify_stream_item(item) when is_binary(item), do: :text
  defp classify_stream_item(%RealtimeEvent{type: type}), do: type
  defp classify_stream_item({:content_part, part}), do: Map.get(part, :type, :content_part)
  defp classify_stream_item({type, _value}) when is_atom(type), do: type
  defp classify_stream_item(_item), do: :unknown

  defp chunk_bytes(text) when is_binary(text), do: byte_size(text)
  defp chunk_bytes(%RealtimeEvent{data: data}) when is_binary(data), do: byte_size(data)
  defp chunk_bytes({:content_part, %{text: text}}) when is_binary(text), do: byte_size(text)
  defp chunk_bytes({:content_part, %{data: data}}) when is_binary(data), do: byte_size(data)
  defp chunk_bytes({:audio, data}) when is_binary(data), do: byte_size(data)
  defp chunk_bytes({:transcript, text}) when is_binary(text), do: byte_size(text)
  defp chunk_bytes({:thinking, text}) when is_binary(text), do: byte_size(text)

  defp chunk_bytes({:tool_call_delta, %{function: %{"arguments" => arguments}}})
       when is_binary(arguments),
       do: byte_size(arguments)

  defp chunk_bytes(_item), do: 0

  defp stream_event_count({:provider_event, _event}), do: 1
  defp stream_event_count({:event, _event}), do: 1
  defp stream_event_count(%RealtimeEvent{type: :provider_event}), do: 1
  defp stream_event_count(_item), do: 0

  defp finish_reason_from_item(%RealtimeEvent{type: :meta, data: meta}) when is_map(meta),
    do: Map.get(meta, :finish_reason)

  defp finish_reason_from_item({:meta, meta}) when is_map(meta), do: Map.get(meta, :finish_reason)
  defp finish_reason_from_item(_item), do: nil

  defp stream_error_metadata(%RealtimeEvent{type: :error, data: error}) when is_map(error) do
    %{
      error_message: Map.get(error, :message) || Map.get(error, "message") || inspect(error),
      error_type: Map.get(error, :type) || Map.get(error, "type")
    }
  end

  defp stream_error_metadata({:error, %{message: message, type: type}}) do
    %{error_message: message, error_type: type}
  end

  defp stream_error_metadata({:error, error}) do
    %{error_message: inspect(error)}
  end

  defp sanitize_metadata(metadata) when is_map(metadata) do
    metadata
    |> Enum.reject(fn {key, _value} -> sensitive_key?(key) end)
    |> Enum.map(fn {key, value} -> {key, sanitize_value(key, value)} end)
    |> Map.new()
  end

  defp sanitize_value(key, value) when is_map(value) do
    if sensitive_key?(key), do: "[REDACTED]", else: sanitize_metadata(value)
  end

  defp sanitize_value(key, value) when is_list(value) do
    if sensitive_key?(key) do
      "[REDACTED]"
    else
      Enum.map(value, &sanitize_list_item(key, &1))
    end
  end

  defp sanitize_value(key, value) when is_binary(value) do
    if sensitive_key?(key), do: "[REDACTED]", else: truncate_binary(value)
  end

  defp sanitize_value(_key, value), do: value

  defp sanitize_list_item(key, value) when is_map(value), do: sanitize_value(key, value)
  defp sanitize_list_item(key, value) when is_binary(value), do: sanitize_value(key, value)
  defp sanitize_list_item(_key, value), do: value

  defp sensitive_key?(key) when is_binary(key) do
    Enum.any?(@sensitive_keys, &(Atom.to_string(&1) == key))
  end

  defp sensitive_key?(key) when is_atom(key), do: key in @sensitive_keys
  defp sensitive_key?(_key), do: false

  defp truncate_binary(value) when byte_size(value) > 512 do
    binary_part(value, 0, 512)
  end

  defp truncate_binary(value), do: value

  defp safe_model_spec(%LLMDB.Model{provider: provider, id: id}), do: "#{provider}:#{id}"
  defp safe_model_spec(model_spec) when is_binary(model_spec), do: model_spec
  defp safe_model_spec(_model_spec), do: nil

  defp model_id(%LLMDB.Model{id: id}), do: id
  defp model_id(_model), do: nil

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_measurement(map, _key, nil), do: map
  defp maybe_put_measurement(map, key, value) when is_integer(value), do: Map.put(map, key, value)
  defp maybe_put_measurement(map, key, value) when is_float(value), do: Map.put(map, key, value)
  defp maybe_put_measurement(map, _key, _value), do: map

  defp merge_error_metadata(metadata, nil), do: metadata

  defp merge_error_metadata(metadata, error) do
    metadata
    |> Map.put(:error_module, inspect(error.__struct__))
    |> Map.put(:error_message, Exception.message(error))
  rescue
    _ -> Map.put(metadata, :error_message, inspect(error))
  end

  defp exception_metadata(error, _stacktrace) do
    %{error_module: inspect(error.__struct__), error_message: Exception.message(error)}
  rescue
    _ -> %{error_message: inspect(error)}
  end
end
