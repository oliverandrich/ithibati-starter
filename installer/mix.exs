defmodule IthibatiNew.MixProject do
  use Mix.Project

  def project do
    [
      app: :ithibati_new,
      version: "0.9.0",
      elixir: "~> 1.20",
      deps: [],
      description: "Mix archive that creates a Phoenix application with Ithibati Starter",
      package: [
        links: %{"GitHub" => "https://github.com/oliverandrich/ithibati-starter"},
        files: ~w(lib mix.exs README.md LICENSE),
        licenses: ["MIT"]
      ]
    ]
  end
end
