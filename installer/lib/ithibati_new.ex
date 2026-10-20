defmodule IthibatiNew do
  @moduledoc "Builds the Igniter invocation for an opinionated Phoenix project."

  # The archive and the starter share one version.
  @starter "ithibati_starter@#{Mix.Project.config()[:version]}"
  @switches [
    brand: :string,
    license: :string,
    copyright: :string,
    source_url: :string,
    yes: :boolean,
    starter: :string
  ]

  # The archives this one is tested with. Docs and scripts name the same versions.
  @generators [
    {"phx.new", "phx_new", "1.8.16"},
    {"igniter.new", "igniter_new", "0.5.35"}
  ]

  def generators, do: @generators

  def arguments(args) do
    {opts, paths} = OptionParser.parse!(args, strict: @switches)

    path =
      case paths do
        [path] ->
          path

        _ ->
          Mix.raise(
            "Usage: mix ithibati.new PATH [--brand COLOUR] [--license mit|agpl] " <>
              "[--copyright NAME] [--source-url URL] [--no-yes]"
          )
      end

    [
      path,
      "--with",
      "phx.new",
      "--install",
      Keyword.get(opts, :starter, @starter),
      "--only",
      "dev"
    ] ++
      Enum.flat_map(
        [
          brand: "--brand",
          license: "--license",
          copyright: "--copyright",
          source_url: "--source-url"
        ],
        fn {key, flag} ->
          if opts[key], do: [flag, opts[key]], else: []
        end
      ) ++
      if(Keyword.get(opts, :yes, true), do: ["--yes"], else: [])
  end
end
