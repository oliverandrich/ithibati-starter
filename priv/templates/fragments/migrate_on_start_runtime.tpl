
# A release brings its schema up to date as it starts. An operator who migrates by hand, with
# bin/migrate, turns that off. Development data is never migrated by starting a server.
if config_env() == :prod do
  migrate_on_start =
    case "__APP_UPCASE___MIGRATE_ON_START" |> System.get_env("") |> String.trim() do
      value when value in ["", "true"] ->
        true

      "false" ->
        false

      other ->
        raise """
        environment variable __APP_UPCASE___MIGRATE_ON_START is neither true nor false: #{inspect(other)}
        """
    end

  config :__APP__, :migrate_on_start, migrate_on_start
end
