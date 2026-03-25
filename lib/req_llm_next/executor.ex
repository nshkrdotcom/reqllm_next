defmodule ReqLlmNext.Executor do
  @moduledoc """
  Executes planned ReqLLM v2 requests without choosing behavior itself.

  The executor owns:

  1. top-level facade dispatch
  2. fixture replay versus live execution
  3. adapter application for the selected plan
  4. transport invocation through the resolved execution modules
  5. buffering and response materialization
  """

  alias ReqLlmNext.Adapters.Pipeline, as: AdapterPipeline

  alias ReqLlmNext.{
    Context,
    ExecutionModules,
    Error,
    Fixtures,
    ModelResolver,
    ObjectDecoder,
    ObjectPrompt,
    OperationPlanner,
    Response,
    Schema,
    SessionRuntime,
    Speech,
    StreamResponse
  }

  alias ReqLlmNext.Transcription

  @spec generate_text(ReqLlmNext.model_spec(), String.t() | Context.t(), keyword()) ::
          {:ok, Response.t()} | {:error, term()}
  def generate_text(model_spec, prompt, opts \\ []) do
    with {:ok, %StreamResponse{} = stream_resp} <- stream_text(model_spec, prompt, opts),
         {:ok, context} <- Context.normalize(prompt) do
      stream = stream_resp.stream
      model = stream_resp.model

      streaming_response = %Response{
        id: generate_id(),
        model: model,
        context: context,
        message: nil,
        stream?: true,
        stream: stream,
        usage: nil,
        finish_reason: nil
      }

      Response.join_stream(streaming_response)
    end
  end

  defp generate_id do
    Uniq.UUID.uuid7()
  end

  @spec stream_text(ReqLlmNext.model_spec(), String.t() | Context.t(), keyword()) ::
          {:ok, StreamResponse.t()} | {:error, term()}
  def stream_text(model_spec, prompt, opts \\ []) do
    with {:ok, model} <- ModelResolver.resolve(model_spec),
         {:ok, plan} <-
           OperationPlanner.plan(
             model,
             :text,
             prompt,
             opts
             |> Keyword.put(:_stream?, true)
             |> Keyword.put(:_model_spec, inspect_model_spec(model_spec))
           ),
         %{
           provider_mod: provider_mod,
           session_runtime_mod: session_runtime_mod,
           protocol_mod: protocol_mod,
           wire_mod: wire_mod,
           transport_mod: transport_mod
         } <-
           ExecutionModules.resolve(plan),
         {:ok, runtime_opts} <- runtime_opts(plan, model, opts, session_runtime_mod) do
      case Fixtures.maybe_replay_stream(model, prompt, runtime_opts) do
        {:ok, replay_stream} ->
          {:ok, StreamResponse.new!(%{stream: replay_stream, model: model})}

        :no_fixture ->
          with {:ok, stream} <-
                 transport_mod.stream(
                   provider_mod,
                   protocol_mod,
                   wire_mod,
                   model,
                   prompt,
                   runtime_opts
                 ) do
            {:ok, StreamResponse.new!(%{stream: stream, model: model})}
          end
      end
    end
  end

  @spec stream_object(ReqLlmNext.model_spec(), String.t() | Context.t(), term(), keyword()) ::
          {:ok, StreamResponse.t()} | {:error, term()}
  def stream_object(model_spec, prompt, object_schema, opts \\ []) do
    with {:ok, model} <- ModelResolver.resolve(model_spec),
         {:ok, compiled_schema} <- ReqLlmNext.Schema.compile(object_schema),
         planning_opts <-
           opts
           |> Keyword.put(:operation, :object)
           |> Keyword.put(:compiled_schema, compiled_schema)
           |> Keyword.put(:_stream?, true)
           |> Keyword.put(:_model_spec, inspect_model_spec(model_spec)),
         {:ok, plan} <- OperationPlanner.plan(model, :object, prompt, planning_opts),
         {:ok, execution_prompt} <- object_prompt(prompt, plan, compiled_schema),
         %{
           provider_mod: provider_mod,
           session_runtime_mod: session_runtime_mod,
           protocol_mod: protocol_mod,
           wire_mod: wire_mod,
           transport_mod: transport_mod
         } <-
           ExecutionModules.resolve(plan),
         {:ok, runtime_opts} <- runtime_opts(plan, model, opts, session_runtime_mod) do
      case Fixtures.maybe_replay_stream(model, execution_prompt, runtime_opts) do
        {:ok, replay_stream} ->
          {:ok, StreamResponse.new!(%{stream: replay_stream, model: model})}

        :no_fixture ->
          with {:ok, stream} <-
                 transport_mod.stream(
                   provider_mod,
                   protocol_mod,
                   wire_mod,
                   model,
                   execution_prompt,
                   runtime_opts
                 ) do
            {:ok, StreamResponse.new!(%{stream: stream, model: model})}
          end
      end
    end
  end

  @spec generate_object(ReqLlmNext.model_spec(), String.t() | Context.t(), term(), keyword()) ::
          {:ok, Response.t()} | {:error, term()}
  def generate_object(model_spec, prompt, object_schema, opts \\ []) do
    with {:ok, compiled_schema} <- Schema.compile(object_schema),
         {:ok, %StreamResponse{} = stream_resp} <-
           stream_object(model_spec, prompt, object_schema, opts),
         {:ok, context} <- Context.normalize(prompt) do
      json_text = StreamResponse.text(stream_resp)
      model = stream_resp.model

      case ObjectDecoder.decode(json_text) do
        {:ok, object} ->
          case Schema.validate(object, compiled_schema) do
            {:ok, validated_object} ->
              {:ok, build_object_response(model, validated_object, context)}

            {:error, {:validation_errors, errors}} ->
              {:error,
               Error.API.SchemaValidation.exception(
                 message: "Schema validation failed",
                 errors: errors,
                 value: object
               )}
          end

        {:error, jason_error} ->
          {:error,
           Error.API.JsonParse.exception(
             message: "Failed to parse JSON: #{Exception.message(jason_error)}",
             raw_json: json_text
           )}
      end
    end
  end

  @spec generate_image(ReqLlmNext.model_spec(), String.t() | Context.t(), keyword()) ::
          {:ok, Response.t()} | {:error, term()}
  def generate_image(model_spec, prompt, opts \\ []) do
    with {:ok, model} <- ModelResolver.resolve(model_spec),
         {:ok, plan} <-
           safe_plan(model, :image, prompt, model_spec, opts),
         %{
           provider_mod: provider_mod,
           session_runtime_mod: session_runtime_mod,
           wire_mod: wire_mod,
           transport_mod: transport_mod
         } <- ExecutionModules.resolve(plan),
         {:ok, runtime_opts} <- runtime_opts(plan, model, opts, session_runtime_mod) do
      transport_mod.request(provider_mod, wire_mod, model, prompt, runtime_opts)
    end
  end

  @spec transcribe(
          ReqLlmNext.model_spec(),
          String.t() | {:binary, binary(), String.t()} | {:base64, String.t(), String.t()},
          keyword()
        ) :: {:ok, Transcription.Result.t()} | {:error, term()}
  def transcribe(model_spec, audio, opts \\ []) do
    with {:ok, model} <- ModelResolver.resolve(model_spec),
         {:ok, plan} <- safe_plan(model, :transcription, audio, model_spec, opts),
         %{
           provider_mod: provider_mod,
           session_runtime_mod: session_runtime_mod,
           wire_mod: wire_mod,
           transport_mod: transport_mod
         } <- ExecutionModules.resolve(plan),
         {:ok, runtime_opts} <- runtime_opts(plan, model, opts, session_runtime_mod) do
      transport_mod.request(provider_mod, wire_mod, model, audio, runtime_opts)
    end
  end

  @spec speak(ReqLlmNext.model_spec(), String.t(), keyword()) ::
          {:ok, Speech.Result.t()} | {:error, term()}
  def speak(model_spec, text, opts \\ []) do
    with {:ok, model} <- ModelResolver.resolve(model_spec),
         {:ok, plan} <- safe_plan(model, :speech, text, model_spec, opts),
         %{
           provider_mod: provider_mod,
           session_runtime_mod: session_runtime_mod,
           wire_mod: wire_mod,
           transport_mod: transport_mod
         } <- ExecutionModules.resolve(plan),
         {:ok, runtime_opts} <- runtime_opts(plan, model, opts, session_runtime_mod) do
      transport_mod.request(provider_mod, wire_mod, model, text, runtime_opts)
    end
  end

  defp build_object_response(model, object, context) do
    message = %Context.Message{
      role: :assistant,
      content: [Context.ContentPart.text(Jason.encode!(object))],
      metadata: %{}
    }

    updated_context = Context.append(context, message)

    %Response{
      id: generate_id(),
      model: model,
      context: updated_context,
      message: message,
      object: object,
      stream?: false,
      stream: nil,
      usage: nil,
      finish_reason: :stop
    }
  end

  @spec embed(ReqLlmNext.model_spec(), String.t() | [String.t()], keyword()) ::
          {:ok, [float()] | [[float()]]} | {:error, term()}
  def embed(model_spec, input, opts \\ []) do
    with {:ok, model} <- ModelResolver.resolve(model_spec),
         :ok <- validate_embedding_input(input),
         {:ok, plan} <-
           OperationPlanner.plan(
             model,
             :embed,
             input,
             opts |> Keyword.put(:_model_spec, inspect_model_spec(model_spec))
           ),
         %{
           provider_mod: provider_mod,
           session_runtime_mod: session_runtime_mod,
           wire_mod: wire_mod,
           transport_mod: transport_mod
         } <- ExecutionModules.resolve(plan),
         {:ok, runtime_opts} <- runtime_opts(plan, model, opts, session_runtime_mod),
         {:ok, raw_response} <-
           transport_mod.request(provider_mod, wire_mod, model, input, runtime_opts) do
      wire_mod.extract_embeddings(raw_response, input)
    end
  end

  defp runtime_opts(plan, model, user_opts, session_runtime_mod) do
    plan.parameter_values
    |> Enum.into([])
    |> Keyword.drop([:transport])
    |> then(&AdapterPipeline.apply_modules(plan.plan_adapters, model, &1))
    |> SessionRuntime.prepare(session_runtime_mod, plan, user_opts)
    |> case do
      {:ok, prepared_opts} ->
        {:ok,
         Keyword.merge(
           prepared_opts,
           _execution_surface_id: plan.surface.id,
           _execution_semantic_protocol: plan.semantic_protocol,
           _execution_wire_format: plan.wire_format,
           _execution_transport: plan.transport,
           _structured_output_strategy: Map.get(plan.surface.features, :structured_output),
           _session_strategy: plan.session_strategy,
           _session_runtime: plan.session_runtime
         )}

      {:error, _} = error ->
        error
    end
  end

  defp object_prompt(prompt, plan, compiled_schema) do
    case plan.surface.features.structured_output do
      :prompt_and_parse ->
        {:ok, ObjectPrompt.for_prompt_and_parse(prompt, compiled_schema)}

      _ ->
        {:ok, prompt}
    end
  end

  defp inspect_model_spec(model_spec) when is_binary(model_spec), do: model_spec
  defp inspect_model_spec(_), do: nil

  defp safe_plan(model, operation, input, model_spec, opts) do
    OperationPlanner.plan(
      model,
      operation,
      input,
      opts |> Keyword.put(:_model_spec, inspect_model_spec(model_spec))
    )
  rescue
    error in [
      Error.Invalid.Capability,
      Error.Invalid.Parameter,
      Error.Validation.Error
    ] ->
      {:error, error}
  end

  defp validate_embedding_input("") do
    {:error, Error.Invalid.Parameter.exception(parameter: "input: cannot be empty")}
  end

  defp validate_embedding_input(text) when is_binary(text), do: :ok

  defp validate_embedding_input([]) do
    {:error, Error.Invalid.Parameter.exception(parameter: "input: cannot be empty list")}
  end

  defp validate_embedding_input(texts) when is_list(texts) do
    if Enum.all?(texts, &is_binary/1) do
      if Enum.any?(texts, &(&1 == "")) do
        {:error, Error.Invalid.Parameter.exception(parameter: "input: contains empty string")}
      else
        :ok
      end
    else
      {:error, Error.Invalid.Parameter.exception(parameter: "input: all items must be strings")}
    end
  end

  defp validate_embedding_input(_) do
    {:error,
     Error.Invalid.Parameter.exception(parameter: "input: must be string or list of strings")}
  end
end
