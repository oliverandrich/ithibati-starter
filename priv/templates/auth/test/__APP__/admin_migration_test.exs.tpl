defmodule __MODULE__.AdminMigrationTest do
  @moduledoc """
  The migration that adds the administrator flag, rolled back and run again in the sandbox.

  The account that claimed the instance becomes its administrator; every other account stays a
  member. An application generated before the flag gains this file and runs it on its accounts.
  """
  use __MODULE__.DataCase, async: false

  alias __MODULE__.Accounts.User

  @path "priv/repo/migrations/20261019100000_add_admin_to_users.exs"
  @version @path |> Path.basename() |> Integer.parse() |> elem(0)
  @migration __MODULE__.Repo.Migrations.AddAdminToUsers

  setup do
    unless Code.ensure_loaded?(@migration),
      do: Code.require_file(Application.app_dir(:__APP__, @path))

    :ok
  end

  # The migration lock takes a second connection, which the sandbox does not hand out.
  defp migrate(direction) do
    opts = [log: false, migration_lock: false]
    :ok = apply(Ecto.Migrator, direction, [Repo, @version, @migration, opts])
  end

  # The schema lists the flag, so the rows are written without it.
  defp user!(username) do
    now = DateTime.utc_now()
    row = %{username: username, inserted_at: now, updated_at: now}
    {1, [%{id: id}]} = Repo.insert_all("users", [row], returning: [:id])
    id
  end

  defp admins, do: Repo.all(from u in User, where: u.admin, select: u.id)

  test "the account that claimed the instance becomes its administrator" do
    migrate(:down)
    ada = user!("ada")
    user!("bo")
    Repo.insert!(%Ithibati.Bootstrap{user_id: ada})

    migrate(:up)

    assert admins() == [ada]
  end

  # Ithibati keeps the claim when the claiming account is deleted, with no account on it.
  test "an instance whose first account is gone has no administrator" do
    migrate(:down)
    user!("bo")
    Repo.insert!(%Ithibati.Bootstrap{user_id: nil})

    migrate(:up)

    assert admins() == []
  end
end
