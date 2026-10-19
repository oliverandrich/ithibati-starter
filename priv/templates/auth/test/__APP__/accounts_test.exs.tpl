defmodule __MODULE__.AccountsTest do
  @moduledoc """
  The administrator role: who grants and revokes it, and that the last one keeps it.
  """
  use __MODULE__.DataCase, async: true

  alias Ithibati.Identity.Sessions
  alias __MODULE__.Accounts
  alias __MODULE__.Accounts.User

  defp account(attrs \\ %{}),
    do: Repo.insert!(struct(%User{username: "u#{System.unique_integer([:positive])}"}, attrs))

  test "an administrator grants the role to a member" do
    admin = account(%{admin: true})
    member = account()

    assert {:ok, %User{admin: true}} = Accounts.grant_admin(admin, member.id)
    assert Repo.reload!(member).admin
  end

  # The flag is read from the database, so a stale struct grants nothing.
  test "a member grants nothing, even with a struct that claims the role" do
    member = account()
    other = account()

    assert Accounts.grant_admin(%{member | admin: true}, other.id) == {:error, :forbidden}
    refute Repo.reload!(other).admin
  end

  test "an unknown account is reported" do
    admin = account(%{admin: true})

    assert Accounts.grant_admin(admin, -1) == {:error, :not_found}
    assert Accounts.revoke_admin(admin, "not an id") == {:error, :not_found}
  end

  test "an administrator revokes the role while another one remains" do
    admin = account(%{admin: true})
    other = account(%{admin: true})

    assert {:ok, %User{admin: false}} = Accounts.revoke_admin(admin, other.id)

    # An administrator may also step down.
    third = account(%{admin: true})
    assert {:ok, %User{admin: false}} = Accounts.revoke_admin(admin, admin.id)
    assert Repo.reload!(third).admin
  end

  test "the last administrator keeps the role" do
    admin = account(%{admin: true})

    assert Accounts.revoke_admin(admin, admin.id) == {:error, :last_admin}
    # An id from a form arrives as a string and names the same account.
    assert Accounts.revoke_admin(admin, to_string(admin.id)) == {:error, :last_admin}
    assert Repo.reload!(admin).admin
  end

  # The role is read when the change is made, not when the acting account was loaded.
  test "an administrator who lost the role changes nothing" do
    admin = account(%{admin: true})
    demoted = account(%{admin: true})
    member = account()
    {:ok, _demoted} = Accounts.revoke_admin(admin, demoted.id)

    assert Accounts.grant_admin(demoted, member.id) == {:error, :forbidden}
    assert Accounts.revoke_admin(member, admin.id) == {:error, :forbidden}
    assert Repo.reload!(admin).admin
  end

  test "with_admin/2 rolls back what fails and runs nothing for a member" do
    admin = account(%{admin: true})
    member = account()

    assert Accounts.with_admin(admin, fn admins -> {:ok, admins} end) == {:ok, [admin.id]}

    assert Accounts.with_admin(admin, fn _admins ->
             Repo.update!(Ecto.Changeset.change(member, name: "changed"))
             {:error, :refused}
           end) == {:error, :refused}

    refute Repo.reload!(member).name
    assert Accounts.with_admin(member, fn _admins -> raise "not called" end) ==
             {:error, :forbidden}
  end

  test "an administrator lists every account by username, a member lists none" do
    admin = account(%{admin: true, username: "zz-admin"})
    member = account(%{username: "aa-member"})

    assert {:ok, accounts} = Accounts.list_accounts(admin)
    assert Enum.map(accounts, & &1.id) == [member.id, admin.id]
    assert Accounts.list_accounts(%{member | admin: true}) == {:error, :forbidden}
  end

  describe "remove_account/2" do
    # The sessions go in the same transaction as the account. Their digests come back for the
    # caller to disconnect after the commit.
    test "an administrator removes a member with its sessions" do
      admin = account(%{admin: true})
      member = account()
      token = Sessions.generate_session_token(member)

      member_id = member.id

      assert {:ok, %{account: %User{id: ^member_id}, digests: [_digest]}} =
               Accounts.remove_account(admin, to_string(member_id))

      refute Repo.get(User, member.id)
      refute Sessions.get_user_by_session_token(token)
    end

    test "another administrator can be removed, the acting one cannot" do
      admin = account(%{admin: true})
      other = account(%{admin: true})

      assert Accounts.remove_account(admin, admin.id) == {:error, :self}
      assert {:ok, %{digests: []}} = Accounts.remove_account(admin, other.id)
      assert Repo.get(User, admin.id)
    end

    test "a member removes nothing, and an unknown account is reported" do
      admin = account(%{admin: true})
      member = account()

      assert Accounts.remove_account(member, admin.id) == {:error, :forbidden}
      assert Accounts.remove_account(admin, -1) == {:error, :not_found}
      assert Accounts.remove_account(admin, "not an id") == {:error, :not_found}
      assert Repo.get(User, admin.id)
    end
  end

  # The operator's way back when no administrator is left, run on the host.
  test "the operator grants the role by identifier, as Ithibati stores it" do
    member = account()

    assert {:ok, %User{admin: true}} =
             Accounts.grant_admin_as_operator(" " <> String.upcase(member.username) <> " ")

    assert Accounts.grant_admin_as_operator("nobody-here") == {:error, :not_found}
  end
end
