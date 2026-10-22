defmodule __MODULE__.AuthCleanup.Worker do
  @moduledoc """
  Runs `__MODULE__.AuthCleanup` on the hourly schedule in config/config.exs.

  One attempt is enough: the next run an hour later deletes what a retry would.
  """
  use Oban.Worker, queue: :maintenance, max_attempts: 1

  @impl true
  def perform(_job), do: {:ok, __MODULE__.AuthCleanup.run()}
end
