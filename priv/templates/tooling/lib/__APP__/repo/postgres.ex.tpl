defmodule __MODULE__.Repo.Postgres do
  @moduledoc "The repository for PostgreSQL. Reached through `__MODULE__.Repo`."

  # `__MODULE__.Repo`, derived from this module's name. `__MODULE__.Repo` compares this module's
  # functions with SQLite's at compile time, so naming it here would add a compile-time cycle.
  @name __ENV__.module |> Module.split() |> Enum.drop(-1) |> Module.concat()

  # The repository registers under that name, so name lookups for `__MODULE__.Repo` find it.
  use Ecto.Repo, otp_app: :__APP__, adapter: Ecto.Adapters.Postgres, default_dynamic_repo: @name

  # Under `:supervisor`, `__MODULE__.Repo` has already merged its configuration beneath the
  # start options. Under `:runtime`, the `__MODULE__.Repo` configuration overrides the given one.
  # `priv` and the telemetry prefix match a single repository.
  @impl true
  def init(type, config) do
    config =
      if type == :runtime,
        do: Keyword.merge(config, Application.get_env(:__APP__, @name, [])),
        else: config

    {:ok,
     config
     |> Keyword.put_new(:priv, "priv/repo")
     |> Keyword.put(:telemetry_prefix, [:__APP__, :repo])}
  end
end
