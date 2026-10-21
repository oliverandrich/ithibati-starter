defmodule __MODULE__.IdentityCheckTest do
  @moduledoc """
  A release refuses to start when its accounts were written in the other identity mode.
  """
  # async: false, because every test changes the application env.
  use __MODULE__.DataCase, async: false

  alias __MODULE__.Accounts.User
  alias __MODULE__.IdentityCheck
  alias __MODULE__.SetupSupport

  defp account(identifier), do: Repo.insert!(%User{username: identifier})

  test "an instance without accounts starts in either mode" do
    for mode <- [:username, :email] do
      SetupSupport.put_identity(mode)
      assert IdentityCheck.verify!() == :ok
    end
  end

  test "accounts in the configured mode start" do
    account("grace")
    SetupSupport.put_identity(:username)
    assert IdentityCheck.verify!() == :ok
  end

  test "named accounts refuse an addressed instance" do
    account("grace")
    SetupSupport.put_identity(:email)
    assert_raise RuntimeError, ~r/account_identity: :email/, &IdentityCheck.verify!/0
  end

  test "addressed accounts refuse a named instance" do
    account("grace@example.org")
    SetupSupport.put_identity(:username)
    assert_raise RuntimeError, ~r/account_identity: :username/, &IdentityCheck.verify!/0
  end

  # Development and tests migrate by hand, so their schema may not be there yet.
  test "is skipped where the release does not migrate" do
    account("grace")
    SetupSupport.put_identity(:email)
    assert IdentityCheck.start_link(skip: true) == :ignore
  end
end
