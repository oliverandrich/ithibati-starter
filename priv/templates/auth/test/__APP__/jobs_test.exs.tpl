defmodule __MODULE__.JobsTest do
  @moduledoc "Background work: which engine Oban uses, where it runs, and what it schedules."
  # The database setting is application config, which is global.
  use __MODULE__.DataCase, async: false

  alias __MODULE__.AuthCleanup
  alias __MODULE__.Jobs
  alias __MODULE__.SetupSupport

  test "the cleanup runs every hour" do
    crontab = Jobs.options(true) |> Keyword.fetch!(:cron) |> Keyword.fetch!(:crontab)

    assert {"0 * * * *", AuthCleanup.Worker} in crontab
  end

  test "each database gets the engine written for it" do
    SetupSupport.put_env(:__APP__, :database, :sqlite)
    assert Jobs.options(true)[:engine] == Oban.Engines.Lite

    SetupSupport.put_env(:__APP__, :database, :postgres)
    assert Jobs.options(true)[:engine] == Oban.Engines.Basic
  end

  # `bin/setup-code` and `bin/grant-admin` start the application without the endpoint. They must
  # not run queued jobs or a second scheduler beside the server.
  test "without a serving endpoint, Oban runs no queues and no plugins" do
    options = Jobs.options(false)

    assert options[:queues] == false
    assert options[:plugins] == false
  end

  test "the worker runs the cleanup and reports its counts" do
    assert {:ok, %{sessions: _, challenges: _, invitations: _}} =
             AuthCleanup.Worker.perform(%Oban.Job{args: %{}})
  end
end
