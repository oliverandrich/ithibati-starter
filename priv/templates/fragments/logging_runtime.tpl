
# One JSON object per line on stdout, at LOG_LEVEL, info unless it says otherwise.
if config_env() == :prod do
  config :logger, level: __MODULE__.Logging.level(System.get_env("LOG_LEVEL"))

  config :logger, :default_handler,
    formatter: __MODULE__.Logging.formatter(),
    filters: __MODULE__.Logging.filters()
end
