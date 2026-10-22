defmodule __MODULE__.Repo.Migrations.AddOban do
  use Ecto.Migration

  # Pinned like the Ithibati migrations: an unpinned call installs whatever schema the library
  # has reached when it runs, and rolls back to a different one.
  def up, do: Oban.Migration.up(version: 14)
  def down, do: Oban.Migration.down(version: 1)
end
