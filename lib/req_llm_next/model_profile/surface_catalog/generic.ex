defmodule ReqLlmNext.ModelProfile.SurfaceCatalog.Generic do
  @moduledoc """
  Metadata-driven surface catalog for best-effort execution on non-first-class providers.
  """

  alias ReqLlmNext.ModelProfile.SurfaceCatalog.Helpers
  alias ReqLlmNext.RuntimeMetadata

  @spec build(LLMDB.Model.t(), map()) :: %{
          family: atom() | nil,
          surfaces: map(),
          session_capabilities: map()
        }
  def build(%LLMDB.Model{} = model, provider_facts) do
    surfaces =
      Enum.reduce([:text, :object, :embed, :image, :transcription, :speech], %{}, fn operation,
                                                                                     acc ->
        case RuntimeMetadata.execution_entry(model, operation) do
          {:ok, entry} ->
            Helpers.maybe_put_surfaces(
              acc,
              operation,
              surfaces_for(model, provider_facts, operation, entry)
            )

          {:error, _reason} ->
            acc
        end
      end)

    %{
      family: RuntimeMetadata.primary_family(model),
      surfaces: surfaces,
      session_capabilities: session_capabilities(surfaces)
    }
  end

  defp surfaces_for(model, provider_facts, operation, entry) do
    case Map.get(entry, :family) do
      "openai_chat_compatible" ->
        [
          Helpers.chat_surface(
            :openai_chat,
            operation,
            :openai_chat,
            :openai_chat_sse_json,
            :http_sse,
            Helpers.surface_features(model, operation, provider_facts),
            [],
            :openai_chat_compatible
          )
        ]

      "openai_responses_compatible" ->
        [
          Helpers.chat_surface(
            :openai_responses,
            operation,
            :openai_responses,
            :openai_responses_sse_json,
            :http_sse,
            Helpers.surface_features(model, operation, provider_facts),
            [Helpers.surface_id(:openai_responses, operation, :websocket)],
            :openai_responses_compatible
          ),
          Helpers.chat_surface(
            :openai_responses,
            operation,
            :openai_responses,
            :openai_responses_ws_json,
            :websocket,
            Map.put(
              Helpers.surface_features(model, operation, provider_facts),
              :persistent_session,
              true
            ),
            [Helpers.surface_id(:openai_responses, operation, :http_sse)],
            :openai_responses_compatible
          )
        ]

      "openai_embeddings" ->
        [Helpers.embedding_surface(:openai_chat_compatible)]

      "openai_images" ->
        [
          Helpers.request_surface(
            :openai_images_image_http,
            :image,
            :openai_images,
            :openai_images_json,
            %{},
            :openai_images
          )
        ]

      "openai_transcription" ->
        [
          Helpers.request_surface(
            :openai_transcription_http,
            :transcription,
            :openai_transcription,
            :openai_transcription_multipart,
            %{},
            :openai_transcriptions
          )
        ]

      "openai_speech" ->
        [
          Helpers.request_surface(
            :openai_speech_http,
            :speech,
            :openai_speech,
            :openai_speech_json,
            %{},
            :openai_speech
          )
        ]

      "anthropic_messages" ->
        [
          Helpers.chat_surface(
            :anthropic_messages,
            operation,
            :anthropic_messages,
            :anthropic_messages_sse_json,
            :http_sse,
            Helpers.surface_features(model, operation, provider_facts),
            [],
            :anthropic_messages
          )
        ]

      "google_generate_content" ->
        [
          Helpers.chat_surface(
            :google_generate_content,
            operation,
            :google_generate_content,
            :google_generate_content_sse_json,
            :http_sse,
            Helpers.surface_features(model, operation, provider_facts),
            [],
            :google_generate_content
          )
        ]

      "cohere_chat" ->
        [
          Helpers.chat_surface(
            :cohere_chat,
            operation,
            :cohere_chat,
            :cohere_chat_sse_json,
            :http_sse,
            Helpers.surface_features(model, operation, provider_facts),
            [],
            :cohere_chat
          )
        ]

      "elevenlabs_speech" ->
        [
          Helpers.request_surface(
            :elevenlabs_speech_http,
            :speech,
            :elevenlabs_speech,
            :elevenlabs_speech_json,
            %{},
            :elevenlabs_speech
          )
        ]

      "elevenlabs_transcription" ->
        [
          Helpers.request_surface(
            :elevenlabs_transcription_http,
            :transcription,
            :elevenlabs_transcription,
            :elevenlabs_transcription_multipart,
            %{},
            :elevenlabs_transcriptions
          )
        ]

      _other ->
        []
    end
  end

  defp session_capabilities(surfaces) do
    persistent =
      surfaces
      |> Map.values()
      |> List.flatten()
      |> Enum.any?(&(Map.get(&1.features, :persistent_session) == true))

    continuation_strategies =
      if persistent do
        [:previous_response_id]
      else
        []
      end

    %{persistent: persistent, continuation_strategies: continuation_strategies}
  end
end
