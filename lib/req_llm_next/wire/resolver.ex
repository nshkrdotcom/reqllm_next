defmodule ReqLlmNext.Wire.Resolver do
  @moduledoc """
  Compatibility metadata resolver built on the current execution architecture.

  New runtime code should plan through `ModelProfile`, `ExecutionSurface`, and
  `ExecutionModules`. This module exists for compatibility-oriented callers and
  tests that still need lightweight catalog questions without re-implementing
  provider or wire selection logic.
  """

  alias ReqLlmNext.{Error, ExecutionModules, Extensions, ModelProfile}
  alias ReqLlmNext.ModelProfile.ProviderFacts.OpenAI, as: OpenAIFacts

  @type resolution :: %{
          provider_mod: module(),
          wire_mod: module()
        }

  @type operation :: :text | :object | :embed | :image | :transcription | :speech

  @spec resolve!(LLMDB.Model.t()) :: resolution()
  def resolve!(%LLMDB.Model{} = model) do
    operation = default_operation!(model)

    resolve_for_operation!(model, operation)
  end

  @doc """
  Checks if a model uses the OpenAI Responses API.

  Determines this from LLMDB metadata only (extra.wire.protocol or extra.api).
  """
  @spec responses_api?(LLMDB.Model.t()) :: boolean()
  def responses_api?(%LLMDB.Model{} = model) do
    OpenAIFacts.responses_api?(model)
  end

  @spec resolve!(LLMDB.Model.t(), operation()) :: resolution()
  def resolve!(%LLMDB.Model{} = model, operation), do: resolve_for_operation!(model, operation)

  @spec provider_module!(LLMDB.Model.t()) :: module()
  def provider_module!(%LLMDB.Model{} = model) do
    %{
      provider_mod: provider_mod
    } = resolve!(model)

    provider_mod
  end

  @spec wire_module!(LLMDB.Model.t()) :: module()
  def wire_module!(%LLMDB.Model{} = model) do
    operation = default_operation!(model)
    wire_module_for_operation!(model, operation)
  end

  defp resolve_for_operation!(%LLMDB.Model{} = model, operation) do
    with {:ok, wire_mod} <- wire_resolution(model, operation),
         {:ok, profile} <- ModelProfile.from_model(model),
         {:ok, provider_mod} <-
           Extensions.provider_module(Extensions.compiled_manifest(), profile.provider) do
      %{
        provider_mod: provider_mod,
        wire_mod: wire_mod
      }
    else
      [] ->
        raise unsupported_operation_error(model, operation)

      {:error, {:unknown_provider, provider}} ->
        raise ArgumentError, "Unable to resolve provider module for #{inspect(provider)}"

      {:error, {:provider_module_not_configured, provider}} ->
        raise ArgumentError, "Provider #{inspect(provider)} does not declare a provider module"

      {:error, reason} ->
        raise ArgumentError, "Unable to resolve model profile: #{inspect(reason)}"
    end
  end

  defp wire_module_for_operation!(%LLMDB.Model{} = model, operation) do
    case wire_resolution(model, operation) do
      {:ok, wire_mod} ->
        wire_mod

      [] ->
        raise unsupported_operation_error(model, operation)

      {:error, reason} ->
        raise ArgumentError, "Unable to resolve model profile: #{inspect(reason)}"
    end
  end

  defp wire_resolution(%LLMDB.Model{} = model, operation) do
    with {:ok, profile} <- ModelProfile.from_model(model),
         [%{wire_format: wire_format} = surface | _] <-
           ModelProfile.surfaces_for(profile, operation) do
      extension_context =
        resolver_extension_context(profile, operation, surface)

      case Extensions.resolve_compiled(extension_context) do
        {:ok, %{seams: %{wire_modules: wire_modules}}} ->
          {:ok, Map.get(wire_modules, wire_format, ExecutionModules.wire_module!(wire_format))}

        {:error, :no_matching_family} ->
          {:ok, ExecutionModules.wire_module!(wire_format)}
      end
    end
  end

  defp resolver_extension_context(profile, operation, surface) do
    %{
      provider: profile.provider,
      family: profile.family,
      model_id: profile.model_id,
      operation: operation,
      transport: surface.transport,
      semantic_protocol: surface.semantic_protocol,
      stream?: Map.get(surface.features, :streaming, false),
      tools?: get_in(profile.features, [:tools, :supported]),
      structured?: operation == :object,
      features: profile.features
    }
  end

  defp default_operation!(%LLMDB.Model{} = model) do
    case ModelProfile.from_model(model) do
      {:ok, profile} ->
        cond do
          ModelProfile.supports_operation?(profile, :text) -> :text
          ModelProfile.supports_operation?(profile, :object) -> :object
          ModelProfile.supports_operation?(profile, :embed) -> :embed
          ModelProfile.supports_operation?(profile, :image) -> :image
          ModelProfile.supports_operation?(profile, :transcription) -> :transcription
          ModelProfile.supports_operation?(profile, :speech) -> :speech
          true -> :text
        end

      {:error, reason} ->
        raise ArgumentError, "Unable to resolve model profile: #{inspect(reason)}"
    end
  end

  defp unsupported_operation_error(model, :embed) do
    Error.Invalid.Capability.exception(message: "Model #{model.id} does not support embeddings")
  end

  defp unsupported_operation_error(model, operation) do
    Error.Invalid.Capability.exception(message: "Model #{model.id} does not support #{operation}")
  end
end
