if System.get_env("__APP_UPCASE___DATABASE", "sqlite") == "sqlite" do
  config :__APP__, __MODULE__.Repo,
    database: Path.expand("../tmp/__APP___test#{System.get_env("MIX_TEST_PARTITION")}.db", __DIR__),
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: System.schedulers_online() * 2
else
  config :__APP__, __MODULE__.Repo,
    username: System.get_env("PGUSER", "postgres"),
    password: System.get_env("PGPASSWORD", "postgres"),
    hostname: System.get_env("PGHOST", "localhost"),
    port: String.to_integer(System.get_env("PGPORT", "5432")),
    database: "__APP___test#{System.get_env("MIX_TEST_PARTITION")}",
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: System.schedulers_online() * 2
end
