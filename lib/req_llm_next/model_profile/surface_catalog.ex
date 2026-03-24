defmodule ReqLlmNext.ModelProfile.SurfaceCatalog do
  @moduledoc """
  Provider-scoped execution-surface and session-capability catalog construction.
  """

  alias ReqLlmNext.ExecutionSurface
  alias ReqLlmNext.ModelHelpers

  @type catalog :: %{
          surfaces: %{optional(ReqLlmNext.ModelProfile.operation()) => [ExecutionSurface.t()]},
          session_capabilities: map()
        }

  @spec build(LLMDB.Model.t(), map()) :: catalog()
  def build(%LLMDB.Model{provider: :anthropic} = model, provider_facts) do
    %{
      surfaces: anthropic_surfaces(model, provider_facts),
      session_capabilities: %{persistent: false, continuation_strategies: []}
    }
  end

  def build(%LLMDB.Model{provider: :openai} = model, provider_facts) do
    %{
      surfaces: openai_surfaces(model, provider_facts),
      session_capabilities: openai_session_capabilities(provider_facts)
    }
  end

  def build(%LLMDB.Model{} = model, provider_facts) do
    %{
      surfaces: default_surfaces(model, provider_facts),
      session_capabilities: %{persistent: false, continuation_strategies: []}
    }
  end

  defp openai_session_capabilities(provider_facts) do
    if Map.get(provider_facts, :responses_api?, false) do
      %{persistent: true, continuation_strategies: [:previous_response_id]}
    else
      %{persistent: false, continuation_strategies: []}
    end
  end

  defp openai_surfaces(model, provider_facts) do
    %{}
    |> maybe_put_surfaces(:text, openai_text_surfaces(model, provider_facts))
    |> maybe_put_surfaces(:object, openai_object_surfaces(model, provider_facts))
    |> maybe_put_surfaces(:embed, openai_embed_surfaces(model))
  end

  defp anthropic_surfaces(model, provider_facts) do
    %{}
    |> maybe_put_surfaces(:text, anthropic_text_surfaces(model, provider_facts))
    |> maybe_put_surfaces(:object, anthropic_object_surfaces(model, provider_facts))
  end

  defp default_surfaces(model, provider_facts) do
    %{}
    |> maybe_put_surfaces(:text, default_text_surfaces(model, provider_facts))
    |> maybe_put_surfaces(:object, default_object_surfaces(model, provider_facts))
  end

  defp maybe_put_surfaces(map, _operation, []), do: map
  defp maybe_put_surfaces(map, operation, surfaces), do: Map.put(map, operation, surfaces)

  defp openai_text_surfaces(model, provider_facts) do
    if chat_supported?(model) do
      openai_chat_surfaces(model, :text, provider_facts)
    else
      []
    end
  end

  defp openai_object_surfaces(model, provider_facts) do
    if chat_supported?(model) do
      openai_chat_surfaces(model, :object, provider_facts)
    else
      []
    end
  end

  defp anthropic_text_surfaces(model, provider_facts) do
    if chat_supported?(model) do
      [
        chat_surface(
          :anthropic_messages,
          :text,
          :anthropic_messages,
          :anthropic_messages_sse_json,
          :http_sse,
          surface_features(model, :text, provider_facts),
          []
        )
      ]
    else
      []
    end
  end

  defp anthropic_object_surfaces(model, provider_facts) do
    if chat_supported?(model) do
      [
        chat_surface(
          :anthropic_messages,
          :object,
          :anthropic_messages,
          :anthropic_messages_sse_json,
          :http_sse,
          surface_features(model, :object, provider_facts),
          []
        )
      ]
    else
      []
    end
  end

  defp default_text_surfaces(model, provider_facts) do
    if chat_supported?(model) do
      [
        chat_surface(
          :openai_chat,
          :text,
          :openai_chat,
          :openai_chat_sse_json,
          :http_sse,
          surface_features(model, :text, provider_facts),
          []
        )
      ]
    else
      []
    end
  end

  defp default_object_surfaces(model, provider_facts) do
    if chat_supported?(model) do
      [
        chat_surface(
          :openai_chat,
          :object,
          :openai_chat,
          :openai_chat_sse_json,
          :http_sse,
          surface_features(model, :object, provider_facts),
          []
        )
      ]
    else
      []
    end
  end

  defp openai_chat_surfaces(model, operation, provider_facts) do
    if Map.get(provider_facts, :responses_api?, false) do
      [
        chat_surface(
          :openai_responses,
          operation,
          :openai_responses,
          :openai_responses_sse_json,
          :http_sse,
          surface_features(model, operation, provider_facts),
          [surface_id(:openai_responses, operation, :websocket)]
        ),
        chat_surface(
          :openai_responses,
          operation,
          :openai_responses,
          :openai_responses_ws_json,
          :websocket,
          Map.put(surface_features(model, operation, provider_facts), :persistent_session, true),
          [surface_id(:openai_responses, operation, :http_sse)]
        )
      ]
    else
      [
        chat_surface(
          :openai_chat,
          operation,
          :openai_chat,
          :openai_chat_sse_json,
          :http_sse,
          surface_features(model, operation, provider_facts),
          []
        )
      ]
    end
  end

  defp openai_embed_surfaces(model) do
    if embeddings_supported?(model) do
      [
        ExecutionSurface.new!(%{
          id: :openai_embeddings_embed_http,
          operation: :embed,
          semantic_protocol: :openai_embeddings,
          wire_format: :openai_embeddings_json,
          transport: :http,
          features: %{streaming: false},
          fallback_ids: []
        })
      ]
    else
      []
    end
  end

  defp chat_surface(
         surface_prefix,
         operation,
         semantic_protocol,
         wire_format,
         transport,
         features,
         fallback_ids
       ) do
    ExecutionSurface.new!(%{
      id: surface_id(surface_prefix, operation, transport),
      operation: operation,
      semantic_protocol: semantic_protocol,
      wire_format: wire_format,
      transport: transport,
      features: features,
      fallback_ids: fallback_ids
    })
  end

  defp surface_id(surface_prefix, operation, transport) do
    :"#{surface_prefix}_#{operation}_#{transport}"
  end

  defp surface_features(model, :text, provider_facts) do
    %{
      streaming: streaming_text_supported?(model),
      tools: tools_supported?(model),
      reasoning: reasoning_supported?(model),
      citations: provider_facts.citations_supported?,
      structured_output: false
    }
  end

  defp surface_features(model, :object, provider_facts) do
    %{
      streaming: streaming_text_supported?(model),
      tools: tools_supported?(model),
      reasoning: reasoning_supported?(model),
      citations: provider_facts.citations_supported?,
      structured_output: object_strategy(model, provider_facts)
    }
  end

  defp object_strategy(model, provider_facts) do
    cond do
      native_structured_outputs?(model, provider_facts) -> :native_json_schema
      chat_supported?(model) -> :prompt_and_parse
      true -> false
    end
  end

  defp native_structured_outputs?(model, provider_facts) do
    ModelHelpers.json_schema?(model) or provider_facts.structured_outputs_native?
  end

  defp chat_supported?(%LLMDB.Model{capabilities: nil}), do: true
  defp chat_supported?(model), do: ModelHelpers.chat?(model)

  defp embeddings_supported?(%LLMDB.Model{capabilities: nil}), do: false
  defp embeddings_supported?(model), do: ModelHelpers.embeddings?(model)

  defp tools_supported?(%LLMDB.Model{capabilities: nil}), do: true
  defp tools_supported?(model), do: ModelHelpers.tools_enabled?(model)

  defp reasoning_supported?(%LLMDB.Model{capabilities: nil}), do: false
  defp reasoning_supported?(model), do: ModelHelpers.reasoning_enabled?(model)

  defp streaming_text_supported?(%LLMDB.Model{capabilities: nil}), do: true
  defp streaming_text_supported?(model), do: ModelHelpers.streaming_text?(model)
end
