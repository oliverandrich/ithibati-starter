defmodule IthibatiNew do
  @moduledoc "Builds the Igniter invocation for an opinionated Phoenix project."

  @starter "ithibati_starter@github:oliverandrich/ithibati-starter@v0.8.0"
  @switches [
    without_beans: :boolean,
    brand: :string,
    yes: :boolean,
    starter: :string
  ]

  def arguments(args) do
    {opts, paths} = OptionParser.parse!(args, strict: @switches)

    path =
      case paths do
        [path] ->
          path

        _ ->
          Mix.raise("Usage: mix ithibati.new PATH [--brand COLOUR] [--without-beans] [--no-yes]")
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
      if(opts[:brand], do: ["--brand", opts[:brand]], else: []) ++
      if(opts[:without_beans], do: ["--without-beans"], else: []) ++
      if(Keyword.get(opts, :yes, true), do: ["--yes"], else: [])
  end
end
