defmodule Mix.Tasks.Auth.Cleanup do
  @moduledoc "Runs the auth cleanup once and reports the counts. Oban also runs it hourly."
  @shortdoc "Deletes expired auth records once"
  use Mix.Task

  @impl true
  def run([]) do
    Mix.Task.run("app.start")
    Mix.shell().info(inspect(__MODULE__.AuthCleanup.run()))
  end
end
