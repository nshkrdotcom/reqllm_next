defmodule ReqLlmNext.Extensions.ManifestVerifierTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Extensions.{Family, Manifest, ManifestVerifier}

  test "requires a global default family" do
    manifest =
      Manifest.new!(%{
        families: [
          %{
            id: :anthropic_messages,
            criteria: %{provider_ids: [:anthropic]},
            seams: %{
              surface_catalog_module: ReqLlmNext.ModelProfile.SurfaceCatalog.AnthropicMessages
            }
          }
        ]
      })

    assert_argument_error("global default family", fn ->
      ManifestVerifier.verify!(manifest)
    end)
  end

  test "requires provider defaults to reference known families" do
    manifest =
      Manifest.new!(%{
        providers: %{
          openai: %{
            id: :openai,
            default_family: :missing_family,
            seams: %{provider_module: ReqLlmNext.Providers.OpenAI}
          }
        },
        families: [
          %{
            id: :openai_chat_compatible,
            default?: true,
            criteria: %{},
            seams: %{
              surface_catalog_module: ReqLlmNext.ModelProfile.SurfaceCatalog.OpenAICompatible
            }
          }
        ]
      })

    assert_argument_error("unknown default family", fn ->
      ManifestVerifier.verify!(manifest)
    end)
  end

  test "rejects duplicate family ids across definition manifests" do
    family =
      Family.new!(%{
        id: :openai_chat_compatible,
        default?: true,
        criteria: %{},
        seams: %{surface_catalog_module: ReqLlmNext.ModelProfile.SurfaceCatalog.OpenAICompatible}
      })

    manifests = [
      Manifest.new!(%{families: [family]}),
      Manifest.new!(%{families: [family]})
    ]

    assert_argument_error("duplicate family id", fn ->
      ManifestVerifier.verify_merge!(manifests)
    end)
  end

  test "rejects ambiguous family criteria at the same priority" do
    manifest =
      Manifest.new!(%{
        families: [
          %{
            id: :openai_chat_compatible,
            priority: 100,
            default?: true,
            criteria: %{provider_ids: [:openai]},
            seams: %{
              surface_catalog_module: ReqLlmNext.ModelProfile.SurfaceCatalog.OpenAICompatible
            }
          },
          %{
            id: :openai_chat_variant,
            priority: 100,
            criteria: %{provider_ids: [:openai]},
            seams: %{
              surface_catalog_module: ReqLlmNext.ModelProfile.SurfaceCatalog.OpenAICompatible
            }
          }
        ]
      })

    assert_argument_error("identical match criteria and priority", fn ->
      ManifestVerifier.verify!(manifest)
    end)
  end

  test "enforces provider seam ownership boundaries" do
    manifest =
      Manifest.new!(%{
        providers: %{
          openai: %{
            id: :openai,
            seams: %{
              provider_module: ReqLlmNext.Providers.OpenAI,
              surface_catalog_module: ReqLlmNext.ModelProfile.SurfaceCatalog.OpenAICompatible
            }
          }
        },
        families: [
          %{
            id: :openai_chat_compatible,
            default?: true,
            criteria: %{},
            seams: %{
              surface_catalog_module: ReqLlmNext.ModelProfile.SurfaceCatalog.OpenAICompatible
            }
          }
        ]
      })

    assert_argument_error("may only declare provider, provider-facts, and utility seams", fn ->
      ManifestVerifier.verify!(manifest)
    end)
  end

  test "enforces family and rule seam ownership boundaries" do
    manifest =
      Manifest.new!(%{
        providers: %{
          openai: %{
            id: :openai,
            default_family: :openai_chat_compatible,
            seams: %{provider_module: ReqLlmNext.Providers.OpenAI}
          }
        },
        families: [
          %{
            id: :openai_chat_compatible,
            default?: true,
            criteria: %{},
            seams: %{
              surface_catalog_module: ReqLlmNext.ModelProfile.SurfaceCatalog.OpenAICompatible,
              utility_modules: %{provider_api: ReqLlmNext.Anthropic}
            }
          }
        ],
        rules: [
          %{
            id: :example_rule,
            criteria: %{provider_ids: [:openai]},
            patch: %{provider_module: ReqLlmNext.Providers.OpenAI}
          }
        ]
      })

    assert_argument_error("may not declare provider or utility seams", fn ->
      ManifestVerifier.verify!(manifest)
    end)
  end

  test "accepts the current compiled manifest" do
    manifest = ReqLlmNext.Extensions.Compiled.manifest()

    assert %Manifest{} = ManifestVerifier.verify!(manifest)
  end

  test "rejects manifests that reference missing seam modules" do
    manifest =
      Manifest.new!(%{
        families: [
          %{
            id: :openai_chat_compatible,
            default?: true,
            criteria: %{},
            seams: %{
              surface_catalog_module: ReqLlmNext.ModelProfile.SurfaceCatalog.OpenAICompatible
            }
          }
        ],
        rules: [
          %{
            id: :invalid_rule,
            criteria: %{},
            patch: %{
              semantic_protocol_modules: %{text: ReqLlmNext.SemanticProtocols.DoesNotExist}
            }
          }
        ]
      })

    assert_argument_error("references unknown module", fn ->
      ManifestVerifier.verify!(manifest)
    end)
  end

  defp assert_argument_error(message, fun) do
    error = assert_raise ArgumentError, fun
    assert error.message =~ message
  end
end
