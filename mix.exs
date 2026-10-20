defmodule IthibatiStarter.MixProject do
  use Mix.Project

  def project do
    [
      app: :ithibati_starter,
      version: "0.9.0",
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
        ],
        docs: [&render_guides/1, "docs"]
      ],
      description: "Opinionated Phoenix starter with invitation-only Ithibati authentication",
      package: [
        links: %{
          "GitHub" => "https://github.com/oliverandrich/ithibati-starter",
          "Ithibati" => "https://github.com/oliverandrich/ithibati"
        },
        files:
          ~w(lib priv docs mix.exs README.md CHANGELOG.md CONTRIBUTING.md LICENSE NOTICE THIRD_PARTY_LICENSES.md),
        licenses: ["MIT"]
      ],
      docs: [
        main: "readme",
        extras:
          ["README.md", "docs/usage.md", "docs/upgrading.md"] ++
            guides() ++ ["CHANGELOG.md", "CONTRIBUTING.md"],
        groups_for_extras: [
          Guides: ["docs/usage.md", "docs/upgrading.md"],
          "Generated application": guides(),
          Project: ["CHANGELOG.md", "CONTRIBUTING.md"]
        ]
      ]
    ]
  end

  @guide_templates "priv/templates/*/docs/*.md.tpl"
  @guide_dir "tmp/guides"

  defp guides, do: Enum.map(Path.wildcard(@guide_templates), &guide/1)
  defp guide(template), do: Path.join(@guide_dir, Path.basename(template, ".tpl"))

  # The guides the installer writes into an application, rendered for HexDocs.
  # The names match the examples in docs/usage.md.
  defp render_guides(_args) do
    Mix.Task.run("compile")
    bindings = %{app: "my_app", module: "MyApp", brand: "violet"}
    File.mkdir_p!(@guide_dir)

    for template <- Path.wildcard(@guide_templates) do
      text = template |> File.read!() |> IthibatiStarter.Files.render(bindings)
      File.write!(guide(template), text)
    end
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
