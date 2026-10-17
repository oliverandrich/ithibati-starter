defmodule __MODULE__.Repo.Migrations.OpenInvitations do
  use Ecto.Migration

  # Schema version 5 lets an invitation leave the name to the invitee. The table was created at
  # version 4, so it opens here, in a migration of its own, and an application generated earlier
  # gains the same file. `up/1` then checks the table at version 5.
  def up do
    Ithibati.Migration.open_invitations(version: 5)
    Ithibati.Migration.up(from: 3, version: 5)
  end

  def down do
    Ithibati.Migration.down(from: 3, version: 5)
    Ithibati.Migration.open_invitations(version: 5)
  end
end
