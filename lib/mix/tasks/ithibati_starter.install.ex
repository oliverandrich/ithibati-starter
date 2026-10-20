defmodule Mix.Tasks.IthibatiStarter.Install do
  @shortdoc "Installs opinionated Phoenix tooling and invitation-only Ithibati authentication"
  @moduledoc """
  Run in a fresh Phoenix 1.8 PostgreSQL application.

      mix igniter.install ithibati_starter --only dev

  Options:
  * `--brand COLOUR`: the Tailwind palette for the brand colour, `violet` by default.
  * `--license LICENSE`: `mit` (the default) or `agpl` for AGPL-3.0-or-later.
  * `--copyright NAME`: the copyright holder in the README and an MIT `LICENSE`; git's `user.name` by default.
  * `--source-url URL`: the address of the application's source code; required with `agpl`.

  Use Igniter's `--dry-run` to preview changes. No database is migrated by installation.
  """
  use Igniter.Mix.Task

  @impl true
  def info(_argv, _source) do
    %Igniter.Mix.Task.Info{
      group: :ithibati_starter,
      schema: [
        brand: :string,
        license: :string,
        copyright: :string,
        source_url: :string
      ]
    }
  end

  @impl true
  def igniter(igniter) do
    opts =
      Keyword.put_new_lazy(igniter.args.options, :copyright, &IthibatiStarter.git_user_name/0)

    IthibatiStarter.install(igniter, opts)
  end
end
