defmodule ReqLlmNext.Extensions.DslTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Extensions
  alias ReqLlmNext.Extensions.{Compiled, Definition, Family, Manifest, Provider, Rule}

  defmodule ExampleDefinition do
    use ReqLlmNext.Extensions.Definition

    providers do
      provider :example do
        default_family(:openai_chat_compatible)
        description("Example OpenAI-compatible provider")

        register do
          provider_module(ReqLlmNext.Providers.OpenAI)
          provider_facts_module(ReqLlmNext.ModelProfile.ProviderFacts.OpenAI)
        end
      end
    end

    families do
      family :openai_chat_compatible do
        default?(true)
        description("Example family")

        match do
          provider_ids([:example])
          features(structured_outputs: [supported: true])
        end

        stack do
          surface_catalog_module(ReqLlmNext.ModelProfile.SurfaceCatalog)
        end
      end

      family :openai_responses_compatible do
        extends(:openai_chat_compatible)
        priority(200)
        description("Example responses family")

        match do
          facts(responses_api?: true)
        end

        stack do
          semantic_protocol_modules(
            openai_responses: ReqLlmNext.SemanticProtocols.OpenAIResponses
          )
        end
      end
    end

    rules do
      rule :example_responses do
        priority(200)

        match do
          family_ids([:openai_responses_compatible])
        end

        patch do
          wire_modules(openai_responses_sse_json: ReqLlmNext.Wire.OpenAIResponses)
        end
      end
    end
  end

  test "Spark definitions persist plain manifest data" do
    manifest = Definition.manifest(ExampleDefinition)

    assert %Manifest{} = manifest
    assert %Provider{} = manifest.providers.example
    assert [%Family{}, %Family{}] = manifest.families
    assert [%Rule{}] = manifest.rules
    assert manifest.providers.example.default_family == :openai_chat_compatible
    assert Enum.any?(manifest.families, &(&1.id == :openai_responses_compatible))

    responses_family =
      Enum.find(manifest.families, &(&1.id == :openai_responses_compatible))

    assert responses_family.extends == :openai_chat_compatible
    assert responses_family.criteria.facts == %{responses_api?: true}

    assert responses_family.seams.semantic_protocol_modules.openai_responses ==
             ReqLlmNext.SemanticProtocols.OpenAIResponses

    assert hd(manifest.rules).patch.wire_modules.openai_responses_sse_json ==
             ReqLlmNext.Wire.OpenAIResponses
  end

  test "merged manifests expand inherited family criteria and seams" do
    manifest = Definition.merge_manifests!([ExampleDefinition])

    responses_family =
      Enum.find(manifest.families, &(&1.id == :openai_responses_compatible))

    assert responses_family.criteria.provider_ids == [:example]
    assert responses_family.seams.surface_catalog_module == ReqLlmNext.ModelProfile.SurfaceCatalog
  end

  test "compiled manifest aggregates built-in definition modules" do
    manifest = Compiled.manifest()

    assert %Manifest{} = manifest

    assert Enum.sort(Compiled.definitions()) ==
             Enum.sort([
               ReqLlmNext.Extensions.Definitions.OpenAICompatible,
               ReqLlmNext.Extensions.Definitions.OpenAI,
               ReqLlmNext.Extensions.Definitions.Anthropic,
               ReqLlmNext.Extensions.Definitions.Alibaba,
               ReqLlmNext.Extensions.Definitions.DeepSeek,
               ReqLlmNext.Extensions.Definitions.Groq,
               ReqLlmNext.Extensions.Definitions.OpenRouter,
               ReqLlmNext.Extensions.Definitions.VLLM,
               ReqLlmNext.Extensions.Definitions.Venice,
               ReqLlmNext.Extensions.Definitions.XAI
             ])

    assert Map.has_key?(manifest.providers, :openai)
    assert Map.has_key?(manifest.providers, :anthropic)
    assert Map.has_key?(manifest.providers, :alibaba)
    assert Map.has_key?(manifest.providers, :groq)
    assert Map.has_key?(manifest.providers, :openrouter)
    assert Map.has_key?(manifest.providers, :vllm)
    assert Map.has_key?(manifest.providers, :venice)
    assert Map.has_key?(manifest.providers, :xai)
    assert Enum.any?(manifest.families, &(&1.id == :openai_chat_compatible))
    assert Enum.any?(manifest.families, &(&1.id == :openai_responses_compatible))
    assert Enum.any?(manifest.families, &(&1.id == :anthropic_messages))
    assert Enum.any?(manifest.families, &(&1.id == :alibaba_chat_compatible))
    assert Enum.any?(manifest.families, &(&1.id == :groq_chat_compatible))
    assert Enum.any?(manifest.families, &(&1.id == :openrouter_chat_compatible))
    assert Enum.any?(manifest.families, &(&1.id == :venice_chat_compatible))
    assert Enum.any?(manifest.families, &(&1.id == :xai_responses_compatible))
    assert Enum.any?(manifest.rules, &(&1.id == :openai_reasoning_models))
    assert {:ok, ReqLlmNext.Providers.OpenAI} = Extensions.provider_module(manifest, :openai)

    responses_family =
      Enum.find(manifest.families, &(&1.id == :openai_responses_compatible))

    assert responses_family.seams.session_runtime_modules.openai_responses ==
             ReqLlmNext.SessionRuntimes.OpenAIResponses

    assert {:ok, ReqLlmNext.Anthropic.Files} =
             Extensions.utility_module(manifest, %{provider: :anthropic}, :files)
  end
end
