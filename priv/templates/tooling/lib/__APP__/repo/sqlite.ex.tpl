defmodule __MODULE__.Repo.SQLite do
  @moduledoc "The repository for SQLite. Reached through `__MODULE__.Repo`."

  # WAL lets readers proceed during a write. `busy_timeout` waits up to five seconds for a lock
  # instead of failing. `:immediate` transactions take the write lock at BEGIN, so none
  # deadlocks upgrading a read.
  @defaults [
    journal_mode: :wal,
    synchronous: :normal,
    temp_store: :memory,
    journal_size_limit: 27_103_364,
    cache_size: 2000,
    busy_timeout: 5000,
    foreign_keys: :on,
    default_transaction_mode: :immediate,
    custom_pragmas: [mmap_size: 134_217_728]
  ]

  # `__MODULE__.Repo`, derived from this module's name. `__MODULE__.Repo` reads this module's
  # functions at compile time, so naming it here would add a compile-time cycle.
  @name __ENV__.module |> Module.split() |> Enum.drop(-1) |> Module.concat()

  # The repository registers under that name, so name lookups for `__MODULE__.Repo` find it.
  use Ecto.Repo, otp_app: :__APP__, adapter: Ecto.Adapters.SQLite3, default_dynamic_repo: @name

  @doc "Returns `query` unchanged. An `:immediate` transaction holds the write lock from BEGIN."
  def for_update(query), do: query

  # Under `:supervisor`, `__MODULE__.Repo` has already merged its configuration beneath the
  # start options. Under `:runtime`, the `__MODULE__.Repo` configuration overrides the given one.
  # `@defaults` sit beneath both. `priv` and the telemetry prefix match a single repository.
  @impl true
  def init(type, config) do
    config =
      if type == :runtime,
        do: Keyword.merge(config, Application.get_env(:__APP__, @name, [])),
        else: config

    config =
      @defaults
      |> Keyword.merge(config)
      |> Keyword.put_new(:priv, "priv/repo")
      |> Keyword.put(:telemetry_prefix, [:__APP__, :repo])

    if type == :supervisor, do: write_ahead(config)
    {:ok, config}
  end

  # Sets WAL on one connection before the pool opens. On a new file, SQLite refuses concurrent
  # switches instead of waiting, so the pool's connections would log "database is locked".
  # A file already in WAL needs no lock to keep it. The pool reports a file that cannot be opened.
  defp write_ahead(config) do
    with :wal <- config[:journal_mode],
         path when is_binary(path) and path != ":memory:" <- config[:database],
         {:ok, db} <- Exqlite.Sqlite3.open(path) do
      Exqlite.Sqlite3.execute(db, "PRAGMA journal_mode = WAL")
      Exqlite.Sqlite3.close(db)
    end

    :ok
  end
end
