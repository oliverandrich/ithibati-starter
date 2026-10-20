defmodule __MODULE__Web.AdministrationFeatureTest do
  use __MODULE__Web.PlaywrightCase

  alias __MODULE__.Accounts.User
  alias __MODULE__.Repo

  defp dialog_open?(conn),
    do: value_of(conn, "() => document.querySelector('#remove-confirm')?.matches(':modal') === true")

  defp focused(conn), do: value_of(conn, "() => document.activeElement.dataset.action || ''")

  test "an administrator confirms the passkey and answers the removal dialog", %{conn: conn} do
    virtual_authenticator(conn)

    conn
    |> unlock_setup()
    |> fill("input[name=username]", "ada")
    |> click_button("Create your passkey")
    |> assert_path("/recovery-codes")

    grace = Repo.insert!(%User{username: "grace"})

    conn
    |> open("/accounts")
    |> connected()
    |> click("#account-#{grace.id} [data-action=remove]")
    |> assert_path("/account/verify")
    |> connected()
    |> click_button("Confirm with a passkey")
    |> assert_path("/accounts")
    |> connected()
    |> click("#account-#{grace.id} [data-action=remove]")
    |> assert_has("#remove-confirm", text: "Remove grace?")

    assert dialog_open?(conn)

    conn
    |> press("#remove-confirm", "Escape")
    |> refute_has("#remove-confirm")

    assert focused(conn) == "remove"

    conn
    |> click("#account-#{grace.id} [data-action=remove]")
    |> assert_has("#remove-confirm", text: "Remove grace?")
    |> click("#cancel-remove")
    |> refute_has("#remove-confirm")

    assert Repo.get(User, grace.id)

    conn
    |> click("#account-#{grace.id} [data-action=remove]")
    |> assert_has("#remove-confirm", text: "Remove grace?")
    |> click("#confirm-remove")
    |> refute_has("#account-#{grace.id}")
    |> assert_has("[role=alert]", text: "Removed grace.")

    refute Repo.get(User, grace.id)
  end
end
