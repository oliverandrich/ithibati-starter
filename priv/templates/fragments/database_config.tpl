# One build serves both databases. __APP_UPCASE___DATABASE chooses one for development and
# tests here, and for a release in config/runtime.exs. __MODULE__.Repo hands every call to the
# repository chosen. SQLite is the default.
database =
  case System.get_env("__APP_UPCASE___DATABASE", "sqlite") do
    "sqlite" -> :sqlite
    "postgres" -> :postgres
    other -> raise "__APP_UPCASE___DATABASE must be sqlite or postgres, not #{inspect(other)}"
  end

config :__APP__, :database, database
