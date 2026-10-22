# Background work runs on the application's own database; __MODULE__.Jobs picks the engine.
config :__APP__, Oban,
  repo: __MODULE__.Repo,
  queues: [maintenance: 1],
  cron: [crontab: [{"0 * * * *", __MODULE__.AuthCleanup.Worker}]],
  pruner: [max_age: 86_400]

