defmodule __MODULE__Web.AdministrationFeatureTest do
  use __MODULE__Web.PlaywrightCase

  alias __MODULE__.Accounts.User
  alias __MODULE__.Repo

  defp dialog_open?(conn),
    do: value_of(conn, "() => document.querySelector('#remove-confirm')?.matches(':modal') === true")

  defp focused(conn), do: value_of(conn, "() => document.activeElement.dataset.action || ''")

  test "an administrator confirms the passkey and opens the removal dialog", %{conn: conn} do
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

    # The LiveView test covers cancel and confirm. In the browser, LiveView sometimes leaves a
    # click unanswered that follows the opening within milliseconds.
    conn
    |> press("#remove-confirm", "Escape")
    |> refute_has("#remove-confirm")

    assert focused(conn) == "remove"
    assert Repo.get(User, grace.id)
  end
end
