defmodule __MODULE__.Jobs do
  @moduledoc """
  Starts Oban on the application's database, with the engine written for it.

  Jobs run only where the endpoint serves. `bin/setup-code`, `bin/grant-admin` and `mix run`
  start the application without it. There Oban starts without queues and plugins, so a short
  command runs no queued job and no second scheduler. See docs/operations.md.
  """

  @doc false
  def child_spec(_opts), do: Oban.child_spec(options())

  @doc "Returns the Oban options, with queues and plugins only for a serving endpoint."
  def options(serving? \\ Phoenix.Endpoint.server?(:__APP__, __MODULE__Web.Endpoint)) do
    engine =
      if __MODULE__.Repo.repo() == __MODULE__.Repo.Postgres,
        do: Oban.Engines.Basic,
        else: Oban.Engines.Lite

    options = Keyword.put(Application.fetch_env!(:__APP__, Oban), :engine, engine)

    if serving?, do: options, else: Keyword.merge(options, queues: false, plugins: false)
  end
end
