defmodule ReqLlmNext.Extensions.ManifestTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Extensions
  alias ReqLlmNext.Extensions.Manifest

  describe "resolve_family/2" do
    test "picks the highest-priority matching family" do
      manifest =
        Manifest.new!(%{
          providers: %{openai: ReqLlmNext.Providers.OpenAI},
          families: [
            %{
              id: :openai_chat_compatible,
              priority: 10,
              default?: true,
              criteria: %{},
              seams: %{surface_catalog_module: ReqLlmNext.ModelProfile.SurfaceCatalog}
            },
            %{
              id: :openai_responses_compatible,
              priority: 100,
              criteria: %{
                provider_ids: [:openai],
                facts: %{responses_api?: true}
              },
              seams: %{surface_catalog_module: ReqLlmNext.ModelProfile.SurfaceCatalog}
            }
          ]
        })

      assert {:ok, family} =
               Extensions.resolve_family(manifest, %{
                 provider: :openai,
                 facts: %{responses_api?: true}
               })

      assert family.id == :openai_responses_compatible
    end

    test "falls back to the default family when no specific family matches" do
      manifest =
        Manifest.new!(%{
          families: [
            %{
              id: :openai_chat_compatible,
              priority: 10,
              default?: true,
              criteria: %{},
              seams: %{surface_catalog_module: ReqLlmNext.ModelProfile.SurfaceCatalog}
            }
          ]
        })

      assert {:ok, family} =
               Extensions.resolve_family(manifest, %{
                 provider: :deepseek,
                 facts: %{responses_api?: false}
               })

      assert family.id == :openai_chat_compatible
    end
  end

  describe "matching_rules/2" do
    test "orders matching rules from broad to narrow so later patches can win" do
      manifest =
        Manifest.new!(%{
          rules: [
            %{
              id: :tools_default,
              priority: 50,
              criteria: %{tools?: true},
              patch: %{adapter_modules: [Kernel]}
            },
            %{
              id: :openai_provider,
              priority: 100,
              criteria: %{provider_ids: [:openai]},
              patch: %{provider_facts_module: ReqLlmNext.ModelProfile.ProviderFacts.OpenAI}
            },
            %{
              id: :gpt4o_mini_specific,
              priority: 200,
              criteria: %{
                provider_ids: [:openai],
                model_ids: ["gpt-4o-mini"]
              },
              patch: %{surface_catalog_module: ReqLlmNext.ModelProfile.SurfaceCatalog}
            }
          ]
        })

      rules =
        Extensions.matching_rules(manifest, %{
          provider: :openai,
          model_id: "gpt-4o-mini",
          tools?: true
        })

      assert Enum.map(rules, & &1.id) == [:tools_default, :openai_provider, :gpt4o_mini_specific]
    end
  end
end
