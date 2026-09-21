defmodule Mix.Tasks.IthibatiStarter.Install do
  @shortdoc "Installs opinionated Phoenix tooling and invitation-only Ithibati authentication"
  @moduledoc """
  Run in a fresh Phoenix 1.8 PostgreSQL application.

      mix igniter.install ithibati_starter --only dev

  Options:
  * `--without-beans`: omit local Beans tracking configuration and commands.

  Use Igniter's `--dry-run` to preview changes. No database is migrated by installation.
  """
  use Igniter.Mix.Task

  @impl true
  def info(_argv, _source) do
    %Igniter.Mix.Task.Info{
      group: :ithibati_starter,
      schema: [without_beans: :boolean],
      defaults: [without_beans: false]
    }
  end

  @impl true
  def igniter(igniter), do: IthibatiStarter.install(igniter, igniter.args.options)
end
