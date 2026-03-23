defmodule ReqLlmNext.MixProject do
  use Mix.Project

  def project do
    [
      app: :req_llm_next,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      elixirc_paths: elixirc_paths(Mix.env()),
      test_coverage: [
        ignore_modules: [
          Mix.Tasks.Llm,
          Mix.Tasks.ReqLlmNext.Gen
        ]
      ],
      dialyzer: [
        plt_add_apps: [:mix],
        ignore_warnings: ".dialyzer_ignore.exs"
      ],
      docs: [
        main: "ReqLlmNext",
        extras: [
          "README.md",
          "guides/package_thesis.md"
        ],
        groups_for_extras: [
          Guides: ["guides/package_thesis.md"]
        ]
      ]
    ]
  end

  def cli do
    [
      preferred_envs: [
        "test.live": :test,
        "test.all": :test,
        "test.parity": :test,
        "test.starter_slice": :test
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger],
      mod: {ReqLlmNext.Application, []}
    ]
  end

  defp deps do
    [
      {:splode, "~> 0.2"},
      {:jason, "~> 1.4"},
      {:finch, "~> 0.19"},
      {:mint_web_socket, "~> 1.0"},
      {:server_sent_events, "~> 0.2"},
      {:llm_db, "~> 2026.3"},
      {:zoi, "~> 0.17"},
      {:spec_led_ex,
       github: "specleddev/specled_ex",
       ref: "e1ec80a7eecc455885fe5f72d5be4612bf15d07e",
       only: [:dev, :test],
       runtime: false},
      {:uniq, "~> 0.6"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      quality: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "dialyzer",
        "credo --strict"
      ],
      q: ["quality"],
      mc: ["req_llm_next.model_compat"],
      test: ["test --exclude integration --exclude live --exclude slow"],
      "test.live": ["test --include live --exclude slow"],
      "test.all": ["test --include integration --include live --include slow"],
      "test.parity": ["test --only parity"],
      "test.starter_slice": [
        "test test/model_slices test/coverage/anthropic_comprehensive_test.exs test/coverage/openai_comprehensive_test.exs"
      ]
    ]
  end
end
