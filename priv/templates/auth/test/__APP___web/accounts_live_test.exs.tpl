defmodule __MODULE__Web.AccountsLiveTest do
  @moduledoc """
  The accounts page lists every account for administrators. Members never reach it.
  """
  use __MODULE__Web.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Ithibati.Identity.Sessions
  alias Ithibati.Web.Gate
  alias __MODULE__.Accounts
  alias __MODULE__.Accounts.User
  alias __MODULE__.Repo

  defp account(attrs \\ %{}),
    do: Repo.insert!(struct(%User{username: "u#{System.unique_integer([:positive])}"}, attrs))

  defp signed_in(conn, account), do: conn |> init_test_session(%{}) |> Gate.log_in(account)

  test "an administrator sees every account with its role", %{conn: conn} do
    admin = account(%{admin: true})
    member = account(%{name: "Grace"})

    {:ok, view, _html} = live(signed_in(conn, admin), ~p"/accounts")

    assert has_element?(view, "#account-#{admin.id}", admin.username)
    assert has_element?(view, "#account-#{admin.id}", "Administrator")
    assert has_element?(view, "#account-#{member.id}", "Grace")
    assert has_element?(view, "#account-#{member.id}", "Member")
    assert has_element?(view, "#accounts-heading", "2 accounts")
    assert has_element?(view, ~s|#nav-back[href="/account/settings"]|)
    assert has_element?(view, ~s|#breadcrumb [aria-current="page"]|, "Accounts")
    assert has_element?(view, ~s|#user-menu a[aria-current="page"][href="/account/settings"]|)
  end

  test "a member is sent to the settings", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/account/settings", flash: flash}}} =
             live(signed_in(conn, account()), ~p"/accounts")

    assert flash["error"] =~ "administrators"
  end

  # One live_session, so the settings reach the page without a full page load.
  test "the settings link the accounts page for administrators only", %{conn: conn} do
    admin = signed_in(conn, account(%{admin: true}))
    {:ok, view, _html} = live(admin, ~p"/account/settings")

    assert {:ok, accounts, _html} =
             view |> element("#settings-admin a", "Accounts") |> render_click() |> follow_redirect(admin)

    assert has_element?(accounts, "#accounts")

    {:ok, view, _html} = live(signed_in(conn, account()), ~p"/account/settings")
    refute has_element?(view, "#settings-admin")
  end

  # The gate loads the account once per mount. A role change reaches an open page as a message.
  test "the settings follow a role granted or revoked while they are open", %{conn: conn} do
    admin = account(%{admin: true})
    member = account()
    {:ok, view, _html} = live(signed_in(conn, member), ~p"/account/settings")

    {:ok, _member} = Accounts.grant_admin(admin, member.id)
    assert has_element?(view, "#settings-admin")

    {:ok, _member} = Accounts.revoke_admin(admin, member.id)
    refute has_element?(view, "#settings-admin")
  end

  # Broadcasts from two processes arrive in any order, so the message only says to read again.
  test "an open page takes the stored role, whatever the message order", %{conn: conn} do
    member = account()
    {:ok, view, _html} = live(signed_in(conn, member), ~p"/account/settings")

    Repo.update!(Ecto.Changeset.change(member, admin: true))
    send(view.pid, :role_changed)
    assert has_element?(view, "#settings-admin")
  end

  test "an administrator whose role is revoked leaves the accounts page", %{conn: conn} do
    admin = account(%{admin: true})
    other = account(%{admin: true})
    {:ok, view, _html} = live(signed_in(conn, other), ~p"/accounts")

    {:ok, _other} = Accounts.revoke_admin(admin, other.id)
    assert_redirect(view, ~p"/account/settings")
  end

  # A confirmation from the last five minutes, as `/account/verify` leaves it in the session.
  defp confirmed(conn, account) do
    conn
    |> Plug.Conn.put_session(:confirmed_account_id, account.id)
    |> Plug.Conn.put_session(:confirmed_at, System.system_time(:second))
  end

  defp action(view, account, name),
    do: view |> element(~s|#account-#{account.id} [data-action="#{name}"]|) |> render_click()

  test "a confirmed administrator grants and revokes the role on a row", %{conn: conn} do
    admin = account(%{admin: true})
    member = account()
    {:ok, view, _html} = live(conn |> signed_in(admin) |> confirmed(admin), ~p"/accounts")

    action(view, member, "grant")
    assert has_element?(view, "#account-#{member.id}", "Administrator")

    action(view, member, "revoke")
    assert has_element?(view, "#account-#{member.id}", "Member")
    refute Repo.reload!(member).admin
  end

  test "a change without a recent confirmation asks for it first", %{conn: conn} do
    admin = account(%{admin: true})
    member = account()
    other = account(%{admin: true})

    for {target, name} <- [{member, "grant"}, {other, "revoke"}, {member, "remove"}] do
      {:ok, view, _html} = live(signed_in(conn, admin), ~p"/accounts")
      assert {:error, {:redirect, %{to: "/account/confirm/accounts"}}} = action(view, target, name)
    end

    assert %{admin: false} = Repo.reload!(member)
    assert %{admin: true} = Repo.reload!(other)

    confirm = get(signed_in(conn, admin), ~p"/account/confirm/accounts")
    assert redirected_to(confirm) == "/account/verify"
    assert get_session(confirm, :reauth_target) == "/accounts"
  end

  test "the own row offers no actions, and a forged event removes nothing", %{conn: conn} do
    admin = account(%{admin: true})
    {:ok, view, _html} = live(conn |> signed_in(admin) |> confirmed(admin), ~p"/accounts")

    refute has_element?(view, "#account-#{admin.id} [data-action]")
    render_click(view, "remove", %{"id" => to_string(admin.id)})
    refute has_element?(view, "#remove-confirm[data-show]")
  end

  test "a confirmed administrator removes an account and ends its open pages", %{conn: conn} do
    admin = account(%{admin: true})
    member = account()
    token = Sessions.generate_session_token(member)
    __MODULE__Web.Endpoint.subscribe(Gate.live_socket_id(token))
    {:ok, view, _html} = live(conn |> signed_in(admin) |> confirmed(admin), ~p"/accounts")

    action(view, member, "remove")
    assert has_element?(view, "#remove-confirm[data-show]", member.username)

    view |> element("#confirm-remove") |> render_click()
    refute has_element?(view, "#account-#{member.id}")
    assert render(view) =~ "Removed #{member.username}."
    refute Repo.get(User, member.id)
    assert_receive %Phoenix.Socket.Broadcast{event: "disconnect"}
  end

  test "cancelling the dialog removes nothing", %{conn: conn} do
    admin = account(%{admin: true})
    member = account()
    {:ok, view, _html} = live(conn |> signed_in(admin) |> confirmed(admin), ~p"/accounts")

    action(view, member, "remove")
    view |> element("#cancel-remove") |> render_click()
    refute has_element?(view, "#remove-confirm[data-show]")
    assert Repo.get(User, member.id)
  end
end
