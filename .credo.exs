%{
  configs: [
    %{
      name: "default",
      strict: true,
      files: %{
        included: ["lib/", "test/", "mix.exs"],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      },
      checks: [
        {Credo.Check.Design.AliasUsage, false},
        {Credo.Check.Readability.AliasOrder, false},
        {Credo.Check.Refactor.CondStatements, false},
        {Credo.Check.Refactor.CyclomaticComplexity, false},
        {Credo.Check.Refactor.Nesting, false},
        {Credo.Check.Warning.ExpensiveEmptyEnumCheck, false}
      ]
    }
  ]
}
