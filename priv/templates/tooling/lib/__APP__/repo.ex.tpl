defmodule __MODULE__.Repo do
  @moduledoc """
  The application's repository. The `:database` setting selects SQLite or PostgreSQL at runtime.

  Ecto fixes a repository's adapter at compile time. So each database has its own repository,
  `__MODULE__.Repo.SQLite` and `__MODULE__.Repo.Postgres`, and this module delegates every call to
  the selected one. Both read their configuration from the `__MODULE__.Repo` key.
  """

  alias __MODULE__.Repo.Postgres
  alias __MODULE__.Repo.SQLite

  @doc "Returns the repository module selected by `:database`."
  def repo do
    case Application.fetch_env!(:__APP__, :database) do
      :sqlite -> SQLite
      :postgres -> Postgres
    end
  end

  # Both adapters give a repository the same functions. A difference after an update fails the
  # build here, instead of one call failing at runtime on one database.
  functions = SQLite.__info__(:functions)

  if functions != Postgres.__info__(:functions),
    do: raise("__MODULE__.Repo.SQLite and __MODULE__.Repo.Postgres define different functions")

  # Delegates every repository function except the start functions below.
  for {name, arity} <- functions, name not in [:init, :start_link, :child_spec] do
    args = Macro.generate_arguments(arity, __ENV__.module)
    def unquote(name)(unquote_splicing(args)), do: repo().unquote(name)(unquote_splicing(args))
  end

  @doc """
  Casts an id from a form to `schema`'s primary key type. Returns `{:ok, id}` or `:error`.

  `get/2` raises `Ecto.Query.CastError` on a value the key cannot hold. The key type is asked of
  the schema, because it is a setting.
  """
  def cast_id(schema, id), do: Ecto.Type.cast(schema.__schema__(:type, :id), id)

  # The selected repository registers under this module's name, so name lookups find it.
  # `Ecto.Adapters.SQL.query/4` and the test sandbox are such lookups.
  # Start options override the `__MODULE__.Repo` configuration, which overrides Ecto's defaults.
  def child_spec(opts), do: repo().child_spec(started(opts))
  def start_link(opts \\ []), do: repo().start_link(started(opts))

  defp started(opts) do
    :__APP__
    |> Application.get_env(__MODULE__.Repo, [])
    |> Keyword.merge(opts)
    |> Keyword.put_new(:name, __MODULE__.Repo)
  end
end
