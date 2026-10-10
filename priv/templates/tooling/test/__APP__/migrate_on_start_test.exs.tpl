defmodule __MODULE__.MigrateOnStartTest do
  @moduledoc """
  What `config/runtime.exs` makes of `__APP_UPCASE___MIGRATE_ON_START`, run against the file itself.

  A release reads it once at boot. A mishandled value shows up as a failed boot, or as a release
  that migrates when its operator said not to.
  """
  use ExUnit.Case, async: false

  # The variables a production boot requires. Mail stays off, so it asks for nothing more.
  @prod %{
    "DATABASE_URL" => "ecto://__APP__:secret@localhost/__APP__",
    "SECRET_KEY_BASE" => String.duplicate("k", 64),
    "MAIL_ENABLED" => nil,
    "ACCOUNT_IDENTITY" => nil
  }

  # A value exported in the developer's shell would otherwise decide the result.
  defp read(mix_env, env) do
    previous = Map.new(env, fn {name, _value} -> {name, System.get_env(name)} end)
    on_exit(fn -> put_env(previous) end)
    put_env(env)

    "config/runtime.exs"
    |> Config.Reader.read!(env: mix_env)
    |> get_in([:__APP__, :migrate_on_start])
  end

  defp put_env(env) do
    Enum.each(env, fn
      {name, nil} -> System.delete_env(name)
      {name, value} -> System.put_env(name, value)
    end)
  end

  defp migrates(value), do: read(:prod, Map.put(@prod, "__APP_UPCASE___MIGRATE_ON_START", value))

  test "a release migrates on start unless told not to" do
    assert migrates(nil) == true
    assert migrates("") == true
    assert migrates("true") == true
    assert migrates("false") == false
  end

  test "anything but true or false stops the boot" do
    assert_raise RuntimeError, ~r/__APP_UPCASE___MIGRATE_ON_START/, fn -> migrates("no") end
  end

  # Development data is migrated by hand, never by starting the server.
  test "development and tests never migrate on start" do
    for mix_env <- [:dev, :test] do
      assert read(mix_env, %{"__APP_UPCASE___MIGRATE_ON_START" => "true"}) == nil
    end
  end
end
