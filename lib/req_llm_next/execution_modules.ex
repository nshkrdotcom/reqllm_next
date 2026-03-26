defmodule ReqLlmNext.ExecutionModules do
  @moduledoc """
  Resolves the runtime modules for a planned execution stack.
  """

  alias ReqLlmNext.{ExecutionPlan, Extensions, Telemetry}

  @type resolution :: %{
          provider_mod: module(),
          session_runtime_mod: module(),
          protocol_mod: module() | nil,
          wire_mod: module(),
          transport_mod: module() | nil
        }

  @spec resolve(ExecutionPlan.t()) :: resolution()
  def resolve(%ExecutionPlan{} = plan) do
    {:ok, %{seams: seams}} = Extensions.resolve_compiled(extension_context(plan))

    resolution = %{
      provider_mod: provider_module_from_seams!(seams, plan),
      session_runtime_mod: session_runtime_module_from_seams!(seams, plan.session_runtime),
      protocol_mod: protocol_module_from_seams!(seams, plan.semantic_protocol),
      wire_mod: wire_module_from_seams!(seams, plan.wire_format),
      transport_mod: transport_module_from_seams!(seams, plan.transport, plan.wire_format)
    }

    Telemetry.emit_execution_stack(plan, resolution)
    resolution
  end

  @spec session_runtime_module!(atom()) :: module()
  def session_runtime_module!(:none), do: ReqLlmNext.SessionRuntimes.None

  def session_runtime_module!(session_runtime) when is_atom(session_runtime) do
    case Map.fetch(
           Extensions.Compiled.runtime_registry().session_runtime_modules,
           session_runtime
         ) do
      {:ok, module} -> module
      :error -> raise("Unknown session runtime: #{inspect(session_runtime)}")
    end
  end

  @spec protocol_module!(atom()) :: module() | nil
  def protocol_module!(semantic_protocol) when is_atom(semantic_protocol) do
    case Map.fetch(
           Extensions.Compiled.runtime_registry().semantic_protocol_modules,
           semantic_protocol
         ) do
      {:ok, module} -> module
      :error -> raise("Unknown semantic protocol: #{inspect(semantic_protocol)}")
    end
  end

  @spec wire_module!(atom()) :: module()
  def wire_module!(wire_format) when is_atom(wire_format) do
    case Map.fetch(Extensions.Compiled.runtime_registry().wire_modules, wire_format) do
      {:ok, module} -> module
      :error -> raise("Unknown wire format: #{inspect(wire_format)}")
    end
  end

  @spec transport_module!(atom(), atom()) :: module() | nil
  def transport_module!(transport, wire_format)
      when is_atom(transport) and is_atom(wire_format) do
    case Map.fetch(Extensions.Compiled.runtime_registry().transport_modules, transport) do
      {:ok, module} ->
        module

      :error ->
        raise("Unknown transport/wire format combination: #{inspect({transport, wire_format})}")
    end
  end

  defp provider_module_from_seams!(%{provider_module: module}, _plan) when not is_nil(module),
    do: module

  defp provider_module_from_seams!(_seams, plan) do
    provider = plan.provider

    case Map.fetch(Extensions.Compiled.runtime_registry().provider_modules, provider) do
      {:ok, module} -> module
      :error -> ReqLlmNext.Providers.Generic
    end
  end

  defp protocol_module_from_seams!(%{semantic_protocol_modules: modules}, semantic_protocol) do
    case Map.fetch(modules, semantic_protocol) do
      {:ok, module} -> module
      :error -> protocol_module!(semantic_protocol)
    end
  end

  defp session_runtime_module_from_seams!(%{session_runtime_modules: _modules}, :none) do
    ReqLlmNext.SessionRuntimes.None
  end

  defp session_runtime_module_from_seams!(%{session_runtime_modules: modules}, session_runtime) do
    case Map.fetch(modules, session_runtime) do
      {:ok, module} -> module
      :error -> session_runtime_module!(session_runtime)
    end
  end

  defp wire_module_from_seams!(%{wire_modules: modules}, wire_format) do
    case Map.fetch(modules, wire_format) do
      {:ok, module} -> module
      :error -> wire_module!(wire_format)
    end
  end

  defp transport_module_from_seams!(%{transport_modules: modules}, transport, wire_format) do
    case Map.fetch(modules, transport) do
      {:ok, module} -> module
      :error -> transport_module!(transport, wire_format)
    end
  end

  defp extension_context(plan) do
    %{
      provider: plan.provider,
      family: plan.surface.family || plan.model.family,
      model_id: plan.model.model_id,
      operation: plan.mode.operation,
      transport: plan.transport,
      semantic_protocol: plan.semantic_protocol,
      stream?: plan.mode.stream?,
      tools?: plan.mode.tools?,
      structured?: plan.mode.structured_output?,
      features: plan.model.features
    }
  end
end
