defmodule __MODULE__.InvitationsTest do
  use __MODULE__.DataCase, async: true

  alias __MODULE__.Accounts.Invitation
  alias __MODULE__.Accounts.User
  alias __MODULE__.Invitations

  defp account(attrs \\ %{}),
    do: Repo.insert!(struct(%User{username: "u#{System.unique_integer([:positive])}"}, attrs))

  test "the inviter takes an invitation back, and its link stops working" do
    inviter = account()
    {:ok, invitation} = Invitations.open(inviter, %{"note" => "Grace"})

    assert {:ok, _gone} = Invitations.withdraw(inviter, invitation)
    refute Ithibati.Identity.Invitations.fetch(invitation.token)
  end

  # The role is read from the database, so a struct that claims it withdraws nothing.
  test "another member withdraws nothing; an administrator withdraws any" do
    {:ok, invitation} = Invitations.open(account(), %{"note" => "Grace"})
    other = account()

    assert Invitations.withdraw(%{other | admin: true}, invitation) == {:error, :forbidden}
    assert Repo.aggregate(Invitation, :count) == 1

    assert {:ok, _gone} = Invitations.withdraw(account(%{admin: true}), invitation)
    assert Repo.aggregate(Invitation, :count) == 0
  end

  # A removal deletes the account while its page may still be open.
  test "an account that is gone opens no invitation" do
    inviter = account()
    Repo.delete!(inviter)

    assert Invitations.open(inviter, %{"note" => "Grace"}) == {:error, :not_found}
    assert Repo.aggregate(Invitation, :count) == 0
  end

  test "the button shows for the inviter and for administrators" do
    inviter = account()
    admin = account(%{admin: true})
    member = account()
    {:ok, invitation} = Invitations.open(inviter, %{"note" => "Grace"})

    assert Invitations.withdrawable?(inviter, invitation)
    assert Invitations.withdrawable?(admin, invitation)
    refute Invitations.withdrawable?(member, invitation)
    assert Invitations.withdraws_any?(admin)
    refute Invitations.withdraws_any?(member)
  end
end
