  # One release serves both databases. __APP_UPCASE___DATABASE chooses one, SQLite unless it says
  # otherwise, and the choice decides the variable that names it. A SQLite file is application
  # data and lives outside the release.
  database =
    case System.get_env("__APP_UPCASE___DATABASE", "sqlite") do
      "sqlite" -> :sqlite
      "postgres" -> :postgres
      other -> raise "__APP_UPCASE___DATABASE must be sqlite or postgres, not #{inspect(other)}"
    end

  config :__APP__, :database, database

  if database == :sqlite do
    database_path =
      case System.get_env("DATABASE_PATH", "") |> String.trim() do
        "/" <> _ = path ->
          path

        _ ->
          raise """
          environment variable DATABASE_PATH is missing or not an absolute path.
          For example: /var/lib/__APP__/__APP__.db
          """
      end

    config :__APP__, __MODULE__.Repo,
      database: database_path,
      pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5")
  else
