defmodule __MODULE__.DatabaseRuntimeTest do
  @moduledoc """
  What `config/runtime.exs` makes of `__APP_UPCASE___DATABASE` in a release, run against the file
  itself. A wrong choice shows up as a failed boot, or as a release writing somewhere unintended.
  """
  use ExUnit.Case, async: false

  alias __MODULE__.RuntimeConfig

  defp read(env) do
    config = RuntimeConfig.read(:prod, env)
    {get_in(config, [:__APP__, :database]), get_in(config, [:__APP__, __MODULE__.Repo])}
  end

  test "a release uses SQLite at an absolute DATABASE_PATH unless told otherwise" do
    assert {:sqlite, repo} = read(%{"DATABASE_PATH" => "/var/lib/__APP__/__APP__.db"})
    assert repo[:database] == "/var/lib/__APP__/__APP__.db"

    for path <- [nil, "", "__APP__.db"] do
      assert_raise RuntimeError, ~r/DATABASE_PATH/, fn -> read(%{"DATABASE_PATH" => path}) end
    end
  end

  test "postgres takes its connection from DATABASE_URL" do
    url = "ecto://__APP__:secret@localhost/__APP__"
    assert {:postgres, repo} = read(%{"__APP_UPCASE___DATABASE" => "postgres", "DATABASE_URL" => url})
    assert repo[:url] == url

    assert_raise RuntimeError, ~r/DATABASE_URL/, fn ->
      read(%{"__APP_UPCASE___DATABASE" => "postgres"})
    end
  end

  test "any other database stops the boot" do
    assert_raise RuntimeError, ~r/__APP_UPCASE___DATABASE/, fn ->
      read(%{"__APP_UPCASE___DATABASE" => "mysql"})
    end
  end
end
