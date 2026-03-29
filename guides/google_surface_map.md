# Google Surface Map

Status: Working Guide  
Last reviewed: 2026-03-28

## Purpose

Document the current Google provider boundary in `ReqLlmNext` so support claims stay aligned with the actual first-class Google slice.

This guide separates:

1. first-class Google surfaces that are implemented in provider-owned code
2. proof depth for those surfaces
3. current honest gaps in the broader Google model and API ecosystem

## Current First-Class Google Support

ReqLlmNext currently treats Google as a native first-class provider family for these lanes:

1. Gemini `generateContent` text generation
2. Gemini `generateContent` structured object generation
3. Gemini streaming over `streamGenerateContent`
4. Gemini multimodal input on the text and object lane
5. Google embeddings through `embedContent` and `batchEmbedContents`
6. Google image generation through dedicated image models and Imagen-style `predict`

The Google provider slice currently lives in:

1. [definition.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/providers/google/definition.ex)
2. [provider_facts.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/providers/google/provider_facts.ex)
3. [surface_catalog_generate_content.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/providers/google/surface_catalog_generate_content.ex)
4. [surface_preparation_generate_content.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/providers/google/surface_preparation_generate_content.ex)
5. [surface_preparation_embeddings.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/providers/google/surface_preparation_embeddings.ex)
6. [surface_preparation_images.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/providers/google/surface_preparation_images.ex)
7. [wire_generate_content.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/providers/google/wire_generate_content.ex)
8. [wire_embeddings.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/providers/google/wire_embeddings.ex)
9. [wire_images.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/providers/google/wire_images.ex)
10. [semantic_protocol_generate_content.ex](/Users/mhostetler/Source/ReqLLM/reqllm_next/lib/req_llm_next/providers/google/semantic_protocol_generate_content.ex)

## Supported Request Features

On the Google `generateContent` lane, ReqLlmNext currently supports:

1. text and object requests
2. streaming
3. native structured outputs
4. function tools
5. Google Search grounding
6. URL context grounding
7. cached-content references
8. safety settings
9. thinking controls

On the dedicated Google media lanes, ReqLlmNext currently supports:

1. embeddings with dimensions and task type
2. image generation for Gemini image models
3. image generation for Imagen models

## Support-Tier Interpretation

Google is a first-class provider, but support still remains operation-specific.

That means:

1. supported Google chat, object, embedding, and image models return `:first_class`
2. Google models that are still catalog-only and do not map to an implemented Google surface return `{:unsupported, :catalog_only}`
3. first-class support comes from actual provider-owned surfaces, not just the provider atom

This matters because Google’s model catalog includes chat, embedding, image, video, audio, and other experimental families that do not all ride the same runtime lane.

## Proof Depth

Current Google proof is strongest at the provider-slice and replay-backed unit level:

1. provider facts and planning in [provider_facts_test.exs](/Users/mhostetler/Source/ReqLLM/reqllm_next/test/providers/google/provider_facts_test.exs) and [execution_stack_test.exs](/Users/mhostetler/Source/ReqLLM/reqllm_next/test/providers/google/execution_stack_test.exs)
2. request shaping and decoding in [wire_generate_content_test.exs](/Users/mhostetler/Source/ReqLLM/reqllm_next/test/providers/google/wire_generate_content_test.exs), [wire_embeddings_test.exs](/Users/mhostetler/Source/ReqLLM/reqllm_next/test/providers/google/wire_embeddings_test.exs), and [wire_images_test.exs](/Users/mhostetler/Source/ReqLLM/reqllm_next/test/providers/google/wire_images_test.exs)
3. public support-tier behavior in [support_status_test.exs](/Users/mhostetler/Source/ReqLLM/reqllm_next/test/public_api/support_status_test.exs)

Current live confidence is still narrower:

1. text smoke is healthy
2. object smoke is healthy
3. embedding smoke is healthy
4. Gemini image-generation smoke is healthy
5. Imagen generation is healthy when used without the unsupported `:size` override
6. sparse live verifier and replay-backed provider-feature coverage now exist for Google baseline, embedding, and image lanes

## Current Honest Gaps

ReqLlmNext does not yet claim first-class support for the broader Google platform surface, including:

1. Files API lifecycle
2. token counting utilities
3. Batch API
4. Live API or canonical Google realtime
5. Google Maps, code execution, and file-search tool helpers
6. video generation families such as Veo
7. music and audio-generation families such as Lyria
8. Vertex-specific wrapper/platform concerns

## Release-Safe Summary

The honest current statement is:

ReqLlmNext has first-class Google support for Gemini `generateContent` text, object, and streaming requests, plus dedicated Google embedding and image-generation lanes. It does not yet cover the full Google platform surface, and unsupported Google model families remain explicit rather than being silently treated as chat-capable.
