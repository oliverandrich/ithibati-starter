defmodule __MODULE__Web.AccountsLiveTest do
  @moduledoc """
  The accounts page lists every account for administrators. Members never reach it.
  """
  use __MODULE__Web.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Ithibati.Web.Gate
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
end
