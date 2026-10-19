defmodule __MODULE__.Repo.Migrations.AddAdminToUsers do
  use Ecto.Migration

  # The table is this application's. A constant default fills existing rows at once.
  # excellent_migrations:safety-assured-for-this-file column_added_with_default
  # One UPDATE grants the role to the claiming account; the migration DSL has no form for it.
  # excellent_migrations:safety-assured-for-this-file raw_sql_executed
  # Removing the column is what reversing this migration means.
  # excellent_migrations:safety-assured-for-this-file column_removed

  # Ithibati records the claiming account in its bootstrap row. Once that account is deleted,
  # the row names none, and the instance has no administrator.
  def up do
    alter table(:users) do
      add :admin, :boolean, null: false, default: false
    end

    execute """
    UPDATE users SET admin = TRUE
    WHERE id IN (SELECT user_id FROM #{Ithibati.Config.table("bootstrap")} WHERE user_id IS NOT NULL)
    """
  end

  def down do
    alter table(:users) do
      remove :admin
    end
  end
end
