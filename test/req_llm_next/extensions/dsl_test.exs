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

        seams do
          provider_module(ReqLlmNext.Providers.OpenAI)
          provider_facts_module(ReqLlmNext.ModelProfile.ProviderFacts.OpenAI)
        end
      end
    end

    families do
      family :openai_chat_compatible do
        default?(true)
        description("Example family")

        criteria do
          provider_ids([:example])
          features(structured_outputs: [supported: true])
        end

        seams do
          surface_catalog_module(ReqLlmNext.ModelProfile.SurfaceCatalog)
        end
      end
    end

    rules do
      rule :example_responses do
        priority(200)

        criteria do
          provider_ids([:example])
          facts(responses_api?: true)
        end

        seams do
          semantic_protocol_modules(text: ReqLlmNext.SemanticProtocols.OpenAIResponses)
        end
      end
    end
  end

  test "Spark definitions persist plain manifest data" do
    manifest = Definition.manifest(ExampleDefinition)

    assert %Manifest{} = manifest
    assert %Provider{} = manifest.providers.example
    assert [%Family{}] = manifest.families
    assert [%Rule{}] = manifest.rules
    assert manifest.providers.example.default_family == :openai_chat_compatible
    assert hd(manifest.families).criteria.features == %{structured_outputs: %{supported: true}}

    assert hd(manifest.rules).patch.semantic_protocol_modules.text ==
             ReqLlmNext.SemanticProtocols.OpenAIResponses
  end

  test "compiled manifest aggregates built-in definition modules" do
    manifest = Compiled.manifest()

    assert %Manifest{} = manifest

    assert Compiled.definitions() == [
             ReqLlmNext.Extensions.Definitions.OpenAICompatible,
             ReqLlmNext.Extensions.Definitions.OpenAI,
             ReqLlmNext.Extensions.Definitions.Anthropic
           ]

    assert Map.has_key?(manifest.providers, :openai)
    assert Map.has_key?(manifest.providers, :anthropic)
    assert Enum.any?(manifest.families, &(&1.id == :openai_chat_compatible))
    assert Enum.any?(manifest.families, &(&1.id == :openai_responses_compatible))
    assert Enum.any?(manifest.families, &(&1.id == :anthropic_messages))
    assert Enum.any?(manifest.rules, &(&1.id == :openai_reasoning_models))
    assert {:ok, ReqLlmNext.Providers.OpenAI} = Extensions.provider_module(manifest, :openai)

    assert {:ok, ReqLlmNext.Anthropic.Files} =
             Extensions.utility_module(manifest, %{provider: :anthropic}, :files)
  end
end
