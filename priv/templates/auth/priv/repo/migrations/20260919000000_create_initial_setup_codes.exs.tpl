defmodule __MODULE__.Repo.Migrations.CreateInitialSetupCodes do
  use Ecto.Migration

  def change do
    create table(:initial_setup_codes) do
      add :digest, :binary, null: false
      timestamps(type: :utc_datetime_usec)
    end
  end
end
