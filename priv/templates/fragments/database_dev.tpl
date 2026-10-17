if System.get_env("__APP_UPCASE___DATABASE", "sqlite") == "sqlite" do
  config :__APP__, __MODULE__.Repo,
    database: Path.expand("../tmp/__APP___dev.db", __DIR__),
    stacktrace: true,
    show_sensitive_data_on_connection_error: true,
    pool_size: 5
else
  config :__APP__, __MODULE__.Repo,
    username: System.get_env("PGUSER", "postgres"),
    password: System.get_env("PGPASSWORD", "postgres"),
    hostname: System.get_env("PGHOST", "localhost"),
    port: String.to_integer(System.get_env("PGPORT", "5432")),
    database: "__APP___dev",
    stacktrace: true,
    show_sensitive_data_on_connection_error: true,
    pool_size: 10
end
