defmodule __MODULE__.Repo.Migrations.CreateInvitations do
  use Ecto.Migration

  # Ours, and it runs before Ithibati's: that migration puts the unique index on `token_hash`.
  #
  # The columns Ithibati reads come from Ithibati, pinned the way its own migration is. What this
  # example would add of its own — a role, a team — goes beside them; there is nothing here
  # because the example is about the flow rather than about what an invitation grants.
  #
  # Pinned at 4 because this table is being created today and the schema macro declares the
  # inviter from that version. Leave the number where it is once this has run: a table made
  # earlier gains the column through `invitation_inviter_column/1` in a migration of its own,
  # never by editing this one.
  def change do
    create table(:invitations) do
      Ithibati.Migration.invitation_columns(version: 4)

      timestamps(type: :utc_datetime_usec)
    end
  end
end
