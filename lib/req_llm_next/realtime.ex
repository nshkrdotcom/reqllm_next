defmodule ReqLlmNext.Realtime do
  @moduledoc """
  First-class, transport-agnostic realtime core.
  """

  alias ReqLlmNext.Error
  alias ReqLlmNext.Extensions
  alias ReqLlmNext.GovernedAuthority
  alias ReqLlmNext.ModelResolver
  alias ReqLlmNext.Realtime.{Command, Event, Session}
  alias ReqLlmNext.Telemetry

  @spec new_session(ReqLlmNext.model_spec(), keyword()) :: {:ok, Session.t()} | {:error, term()}
  def new_session(model_source, _opts \\ []) do
    with {:ok, model} <- ModelResolver.resolve(model_source),
         {:ok, _adapter} <- adapter_module(model) do
      {:ok, Session.new!(%{model: model})}
    end
  end

  @spec encode_command(ReqLlmNext.model_spec(), Command.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def encode_command(model_source, %Command{} = command, opts \\ []) do
    with {:ok, model} <- ModelResolver.resolve(model_source),
         {:ok, adapter} <- adapter_module(model),
         true <- adapter_exports?(adapter, :encode_command, 3) do
      {:ok, adapter.encode_command(model, command, opts)}
    else
      false -> {:error, unsupported_realtime(model_source)}
      {:error, _} = error -> error
    end
  end

  @spec encode_commands(ReqLlmNext.model_spec(), [Command.t()], keyword()) ::
          {:ok, [map()]} | {:error, term()}
  def encode_commands(model_source, commands, opts \\ []) when is_list(commands) do
    Enum.reduce_while(commands, {:ok, []}, fn command, {:ok, acc} ->
      case encode_command(model_source, command, opts) do
        {:ok, encoded} -> {:cont, {:ok, acc ++ [encoded]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  @spec decode_event(ReqLlmNext.model_spec(), map() | binary(), keyword()) ::
          {:ok, [Event.t()]} | {:error, term()}
  def decode_event(model_source, raw_event, opts \\ []) do
    with {:ok, model} <- ModelResolver.resolve(model_source),
         {:ok, adapter} <- adapter_module(model),
         true <- adapter_exports?(adapter, :decode_event, 3) do
      {:ok, adapter.decode_event(raw_event, model, opts)}
    else
      false -> {:error, unsupported_realtime(model_source)}
      {:error, _} = error -> error
    end
  end

  @spec apply_event(Session.t(), Event.t()) :: Session.t()
  def apply_event(%Session{} = session, %Event{} = event) do
    Session.apply_event(session, event)
  end

  @spec apply_events(Session.t(), [Event.t()]) :: Session.t()
  def apply_events(%Session{} = session, events) when is_list(events) do
    Session.apply_events(session, events)
  end

  @spec websocket_url(ReqLlmNext.model_spec(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def websocket_url(model_source, opts \\ []) do
    with :ok <- GovernedAuthority.validate_realtime_opts(opts),
         {:ok, model} <- ModelResolver.resolve(model_source),
         {:ok, adapter} <- adapter_module(model),
         true <- adapter_exports?(adapter, :websocket_url, 2) do
      {:ok, adapter.websocket_url(model, opts)}
    else
      false -> {:error, unsupported_realtime(model_source)}
      {:error, _} = error -> error
    end
  end

  @spec stream(ReqLlmNext.model_spec(), [Command.t()], keyword()) ::
          {:ok, Enumerable.t()} | {:error, term()}
  def stream(model_source, commands, opts \\ []) when is_list(commands) do
    with :ok <- GovernedAuthority.validate_realtime_opts(opts),
         {:ok, model} <- ModelResolver.resolve(model_source),
         {:ok, adapter} <- adapter_module(model),
         true <- adapter_exports?(adapter, :stream_commands, 3),
         {:ok, stream} <- adapter.stream_commands(model, commands, opts) do
      {:ok,
       Telemetry.instrument_stream(
         stream,
         Telemetry.provider_request_metadata(model.provider, model, opts, %{
           semantic_protocol: :realtime,
           transport: :websocket,
           realtime?: true
         })
       )}
    else
      false -> {:error, unsupported_realtime(model_source)}
      {:error, _} = error -> error
    end
  end

  defp adapter_module(%LLMDB.Model{} = model) do
    with {:ok, provider} <- Extensions.provider(Extensions.compiled_manifest(), model.provider),
         {:ok, module} <- Map.fetch(provider.seams.utility_modules, :realtime) do
      {:ok, module}
    else
      :error -> {:error, unsupported_realtime(model)}
      {:error, _} -> {:error, unsupported_realtime(model)}
    end
  end

  defp unsupported_realtime(%LLMDB.Model{id: id}) do
    Error.Invalid.Capability.exception(message: "Model #{id} does not support realtime")
  end

  defp unsupported_realtime(model_source) do
    Error.Invalid.Capability.exception(
      message: "Model #{inspect(model_source)} does not support realtime"
    )
  end

  defp adapter_exports?(adapter, function_name, arity)
       when is_atom(adapter) and is_atom(function_name) and is_integer(arity) do
    Code.ensure_loaded?(adapter) and function_exported?(adapter, function_name, arity)
  end
end
