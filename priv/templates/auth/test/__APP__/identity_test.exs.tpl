defmodule __MODULE__.IdentityTest do
  @moduledoc """
  What an account is called here, and what follows from the answer.

  The mode is one setting, and everything else about it is derived: the shape both schemas
  validate, whether an invitation is deliverable, and whether the instance may start at all.
  """
  # async: false — every test here turns application config around.
  use __MODULE__.DataCase, async: false

  alias __MODULE__.Accounts.Invitation
  alias __MODULE__.Accounts.User
  alias __MODULE__.Identity
  alias __MODULE__.SetupSupport

  defp as(mode), do: SetupSupport.put_identity(mode)

  defp valid?(User, value),
    do: %User{} |> User.changeset(%{"username" => value}) |> Map.fetch!(:valid?)

  defp valid?(Invitation, value),
    do: %Invitation{} |> Invitation.changeset(%{"username" => value}) |> Map.fetch!(:valid?)

  describe "the mode" do
    test "is a name unless something says otherwise" do
      SetupSupport.delete_env(:__APP__, :account_identity)

      assert Identity.mode() == :username
      refute Identity.email?()
    end

    test "is an address when that is what was configured" do
      as(:email)

      assert Identity.mode() == :email
      assert Identity.email?()
    end

    test "is refused when it is neither, and the message names the key" do
      as(:handle)

      assert_raise RuntimeError, ~r/account_identity/, &Identity.mode/0
    end
  end

  describe "what an account and an invitation accept" do
    # Both schemas have to agree. A format enforced on the account but not on the invitation is a
    # form that takes what the ceremony then refuses, with the guest already holding a link.
    test "a name in name mode, and not an address" do
      as(:username)

      for schema <- [User, Invitation] do
        assert valid?(schema, "grace_hopper"), inspect(schema)
        refute valid?(schema, "grace@example.org"), inspect(schema)
      end
    end

    test "an address in address mode, and not a name" do
      as(:email)

      for schema <- [User, Invitation] do
        assert valid?(schema, "grace@example.org"), inspect(schema)
        refute valid?(schema, "grace_hopper"), inspect(schema)
      end
    end

    # The shape is asked before Ithibati mints anything, so a refusal costs neither a token nor a
    # query against the accounts table.
    test "and a refused invitation carries no token" do
      as(:email)

      changeset = Invitation.changeset(%Invitation{}, %{"username" => "grace_hopper"})

      refute changeset.valid?
      refute Ecto.Changeset.get_change(changeset, :token)
    end

    # The refusal has to name the shape. Building it around a changeset that was first made from
    # nothing would leave a blank-field error on a field somebody filled in.
    test "and says what is wrong with it, not that it is missing" do
      as(:email)

      changeset = Invitation.changeset(%Invitation{}, %{"username" => "grace_hopper"})

      assert [username: {message, _meta}] = changeset.errors
      refute message =~ "blank"
    end
  end

  describe "asking for addresses without being able to send any" do
    test "is refused, and the message names both ways out" do
      as(:email)
      SetupSupport.put_env(:__APP__, :mail_enabled, false)

      assert_raise RuntimeError, ~r/MAIL_ENABLED/, &Identity.verify!/0
      assert_raise RuntimeError, ~r/account_identity: :username/, &Identity.verify!/0
    end

    test "is fine once mail is configured" do
      as(:email)
      SetupSupport.put_env(:__APP__, :mail_enabled, true)

      assert Identity.verify!() == :ok
    end

    # An invitation link is handed over however its sender likes, so nothing has to be able to
    # send for a named account to work.
    test "and names never need one" do
      as(:username)
      SetupSupport.put_env(:__APP__, :mail_enabled, false)

      assert Identity.verify!() == :ok
    end
  end
end
