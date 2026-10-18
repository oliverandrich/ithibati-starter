defmodule Mix.Tasks.Ithibati.New do
  @shortdoc "Creates a Phoenix application with Ithibati Starter"
  @moduledoc """
  Creates an opinionated Phoenix application through Igniter.

      mix ithibati.new my_app

  Install the Phoenix 1.8.14 and igniter_new 0.5.34 archives first.
  Ithibati authentication and invitation delivery are always included. Options:

    * `--brand COLOUR` names the Tailwind palette for the brand colour; `violet` by default.
    * `--license mit|agpl` selects MIT (the default) or AGPL-3.0-or-later.
    * `--copyright NAME` names the copyright holder; git's `user.name` by default.
    * `--source-url URL` is the address of the source code; required with `agpl`.
    * `--without-beans` omits local Beans configuration.
    * `--yes` accepts the generator's installation prompts (the default).
    * `--no-yes` restores interactive installation and diff prompts.
    * `--starter SOURCE` selects a local or pinned Igniter package specification;
      defaults to the Starter version of this archive, installed from Hex. See the
      usage guide for other versions and Git revisions.

  This archive belongs to ithibati-starter, not the Ithibati authentication package.
  """
  use Mix.Task

  @impl true
  def run(args) do
    arguments = IthibatiNew.arguments(args)

    for {task, package, version} <- [
          {"phx.new", "phx_new", "1.8.14"},
          {"igniter.new", "igniter_new", "0.5.34"}
        ] do
      unless Mix.Task.get(task) do
        Mix.raise(
          "Install the required generator first: mix archive.install hex #{package} #{version}"
        )
      end
    end

    Mix.Task.run("igniter.new", arguments)
  end
end
