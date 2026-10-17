defmodule __MODULE__.RepoTest do
  use __MODULE__.DataCase, async: true

  alias __MODULE__.Repo

  test "the repository __APP_UPCASE___DATABASE names answers through __MODULE__.Repo" do
    adapter =
      case Application.fetch_env!(:__APP__, :database) do
        :sqlite -> Ecto.Adapters.SQLite3
        :postgres -> Ecto.Adapters.Postgres
      end

    assert Repo.__adapter__() == adapter
    assert %{rows: [[1]]} = Repo.query!("SELECT 1")
  end
end
