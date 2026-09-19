defmodule IthibatiNew do
  @moduledoc "Builds the Igniter invocation for an opinionated Phoenix project."

  @starter "ithibati_starter@github:oliverandrich/ithibati-starter@main"
  @switches [
    with_mail: :boolean,
    without_beans: :boolean,
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
          Mix.raise("Usage: mix ithibati.new PATH [--with-mail] [--without-beans] [--no-yes]")
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
      if(opts[:with_mail], do: ["--with-mail"], else: ["--with-args=--no-mailer"]) ++
      if(opts[:without_beans], do: ["--without-beans"], else: []) ++
      if(Keyword.get(opts, :yes, true), do: ["--yes"], else: [])
  end
end
