
# One JSON object per line at LOG_LEVEL, info unless it says otherwise. LOG_FILE moves the
# lines from stdout into a rotating file.
if config_env() == :prod do
  config :logger, level: __MODULE__.Logging.level(System.get_env("LOG_LEVEL"))

  config :logger, :default_handler,
    formatter: __MODULE__.Logging.formatter(),
    filters: __MODULE__.Logging.filters(),
    config: __MODULE__.Logging.handler_config(System.get_env("LOG_FILE"))
end
