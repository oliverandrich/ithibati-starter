defmodule Mix.Tasks.IthibatiStarter.Install do
  @shortdoc "Installs opinionated Phoenix tooling and invitation-only Ithibati authentication"
  @moduledoc """
  Run in a fresh Phoenix 1.8 PostgreSQL application.

      mix igniter.install ithibati_starter --only dev

  Options:
  * `--with-mail`: add invitation delivery, a Swoosh mailer and development mailbox.
  * `--without-beans`: omit local Beans tracking configuration and commands.

  Use Igniter's `--dry-run` to preview changes. No database is migrated by installation.
  """
  use Igniter.Mix.Task

  @impl true
  def info(_argv, _source) do
    %Igniter.Mix.Task.Info{
      group: :ithibati_starter,
      schema: [with_mail: :boolean, without_beans: :boolean],
      defaults: [with_mail: false, without_beans: false]
    }
  end

  @impl true
  def igniter(igniter), do: IthibatiStarter.install(igniter, igniter.args.options)
end
