defmodule __MODULE__.MigrateOnStartTest do
  @moduledoc """
  What `config/runtime.exs` makes of `__APP_UPCASE___MIGRATE_ON_START`, run against the file itself.

  A release reads it once at boot. A mishandled value shows up as a failed boot, or as a release
  that migrates when its operator said not to.
  """
  use ExUnit.Case, async: false

  alias __MODULE__.RuntimeConfig

  defp read(mix_env, env),
    do: mix_env |> RuntimeConfig.read(env) |> get_in([:__APP__, :migrate_on_start])

  defp migrates(value), do: read(:prod, %{"__APP_UPCASE___MIGRATE_ON_START" => value})

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
