defmodule IthibatiStarter.MixProject do
  use Mix.Project

  def project do
    [
      app: :ithibati_starter,
      version: "0.3.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: [
        precommit: [
          "compile --warnings-as-errors",
          "deps.unlock --check-unused",
          "format --check-formatted",
          "credo --strict",
          "test",
          "cmd --cd installer mix do compile --warnings-as-errors + test + archive.build"
        ]
      ],
      description: "Opinionated Phoenix starter with invitation-only Ithibati authentication",
      package: [
        links: %{
          "GitHub" => "https://github.com/oliverandrich/ithibati-starter",
          "Ithibati" => "https://github.com/oliverandrich/ithibati"
        },
        files:
          ~w(lib priv docs mix.exs README.md CONTRIBUTING.md LICENSE NOTICE THIRD_PARTY_LICENSES.md),
        licenses: ["MIT"]
      ],
      docs: [main: "readme", extras: ["README.md", "CONTRIBUTING.md", "docs/usage.md"]]
    ]
  end

  def cli, do: [preferred_envs: [precommit: :test]]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:igniter, "~> 0.8.4"},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:credo, "~> 1.7.19", only: [:dev, :test], runtime: false},
      {:ex_slop, "~> 0.4.4", only: [:dev, :test], runtime: false},
      {:jump_credo_checks, "~> 0.5.0", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1.5", only: [:dev, :test], runtime: false}
    ]
  end
end
