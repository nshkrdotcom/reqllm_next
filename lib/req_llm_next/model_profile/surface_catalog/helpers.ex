defmodule ReqLlmNext.ModelProfile.SurfaceCatalog.Helpers do
  @moduledoc false

  alias ReqLlmNext.ExecutionSurface
  alias ReqLlmNext.ModelHelpers

  @spec maybe_put_surfaces(map(), ReqLlmNext.ModelProfile.operation(), [ExecutionSurface.t()]) ::
          map()
  def maybe_put_surfaces(map, _operation, []), do: map
  def maybe_put_surfaces(map, operation, surfaces), do: Map.put(map, operation, surfaces)

  @spec chat_surface(atom(), atom(), atom(), atom(), atom(), map(), [atom()], atom() | nil) ::
          ExecutionSurface.t()
  def chat_surface(
        surface_prefix,
        operation,
        semantic_protocol,
        wire_format,
        transport,
        features,
        fallback_ids,
        family \\ nil
      ) do
    ExecutionSurface.new!(%{
      id: surface_id(surface_prefix, operation, transport),
      family: family,
      operation: operation,
      semantic_protocol: semantic_protocol,
      wire_format: wire_format,
      transport: transport,
      features: features,
      fallback_ids: fallback_ids
    })
  end

  @spec embedding_surface(atom() | nil) :: ExecutionSurface.t()
  def embedding_surface(family \\ nil) do
    ExecutionSurface.new!(%{
      id: :openai_embeddings_embed_http,
      family: family,
      operation: :embed,
      semantic_protocol: :openai_embeddings,
      wire_format: :openai_embeddings_json,
      transport: :http,
      features: %{streaming: false},
      fallback_ids: []
    })
  end

  @spec request_surface(
          atom(),
          ReqLlmNext.ModelProfile.operation(),
          atom(),
          atom(),
          map(),
          atom() | nil
        ) ::
          ExecutionSurface.t()
  def request_surface(
        id,
        operation,
        semantic_protocol,
        wire_format,
        features \\ %{},
        family \\ nil
      ) do
    ExecutionSurface.new!(%{
      id: id,
      family: family,
      operation: operation,
      semantic_protocol: semantic_protocol,
      wire_format: wire_format,
      transport: :http,
      features: Map.merge(%{streaming: false}, features),
      fallback_ids: []
    })
  end

  @spec surface_id(atom(), atom(), atom()) :: atom()
  def surface_id(surface_prefix, operation, transport) do
    :"#{surface_prefix}_#{operation}_#{transport}"
  end

  @spec surface_features(LLMDB.Model.t(), :text | :object, map()) :: map()
  def surface_features(model, :text, provider_facts) do
    %{
      streaming: streaming_text_supported?(model),
      tools: tools_supported?(model),
      reasoning: reasoning_supported?(model),
      citations: provider_facts.citations_supported?,
      structured_output: false
    }
  end

  def surface_features(model, :object, provider_facts) do
    %{
      streaming: streaming_text_supported?(model),
      tools: tools_supported?(model),
      reasoning: reasoning_supported?(model),
      citations: provider_facts.citations_supported?,
      structured_output: object_strategy(model, provider_facts)
    }
  end

  @spec object_strategy(LLMDB.Model.t(), map()) :: atom() | false
  def object_strategy(model, provider_facts) do
    cond do
      native_structured_outputs?(model, provider_facts) -> :native_json_schema
      chat_supported?(model, provider_facts) -> :prompt_and_parse
      true -> false
    end
  end

  @spec native_structured_outputs?(LLMDB.Model.t(), map()) :: boolean()
  def native_structured_outputs?(model, provider_facts) do
    ModelHelpers.json_schema?(model) or provider_facts.structured_outputs_native?
  end

  @spec chat_supported?(LLMDB.Model.t()) :: boolean()
  def chat_supported?(%LLMDB.Model{capabilities: nil}), do: true
  def chat_supported?(model), do: ModelHelpers.chat?(model)

  @spec chat_supported?(LLMDB.Model.t(), map()) :: boolean()
  def chat_supported?(_model, %{chat_supported?: value}) when is_boolean(value), do: value
  def chat_supported?(model, _provider_facts), do: chat_supported?(model)

  @spec embeddings_supported?(LLMDB.Model.t()) :: boolean()
  def embeddings_supported?(%LLMDB.Model{capabilities: nil}), do: false
  def embeddings_supported?(model), do: ModelHelpers.embeddings?(model)

  @spec tools_supported?(LLMDB.Model.t()) :: boolean()
  def tools_supported?(%LLMDB.Model{capabilities: nil}), do: true
  def tools_supported?(model), do: ModelHelpers.tools_enabled?(model)

  @spec tools_supported?(LLMDB.Model.t(), map()) :: boolean()
  def tools_supported?(%LLMDB.Model{capabilities: nil} = model, provider_facts) do
    chat_supported?(model, provider_facts)
  end

  def tools_supported?(model, _provider_facts), do: tools_supported?(model)

  @spec reasoning_supported?(LLMDB.Model.t()) :: boolean()
  def reasoning_supported?(%LLMDB.Model{capabilities: nil}), do: false
  def reasoning_supported?(model), do: ModelHelpers.reasoning_enabled?(model)

  @spec reasoning_supported?(LLMDB.Model.t(), map()) :: boolean()
  def reasoning_supported?(%LLMDB.Model{capabilities: nil}, _provider_facts), do: false
  def reasoning_supported?(model, _provider_facts), do: reasoning_supported?(model)

  @spec streaming_text_supported?(LLMDB.Model.t()) :: boolean()
  def streaming_text_supported?(%LLMDB.Model{capabilities: nil}), do: true
  def streaming_text_supported?(model), do: ModelHelpers.streaming_text?(model)

  @spec streaming_text_supported?(LLMDB.Model.t(), map()) :: boolean()
  def streaming_text_supported?(%LLMDB.Model{capabilities: nil} = model, provider_facts) do
    chat_supported?(model, provider_facts)
  end

  def streaming_text_supported?(model, _provider_facts), do: streaming_text_supported?(model)
end
