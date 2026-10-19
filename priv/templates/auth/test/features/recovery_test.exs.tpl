defmodule __MODULE__Web.RecoveryTest do
  use __MODULE__Web.PlaywrightCase

  alias Ithibati.Identity.RecoveryCodes

  test "recovery codes sign in without a passkey and cannot be reused", %{conn: conn} do
    virtual_authenticator(conn)

    codes =
      conn
      |> unlock_setup()
      |> fill("input[name=username]", "ada")
      |> click_button("Create your passkey")
      |> assert_path("/recovery-codes")
      |> assert_has("main li", count: 12)
      |> value_of("() => Array.from(document.querySelectorAll('main li'), li => li.textContent.trim())")

    [code | _] = codes

    conn
    |> clear_cookies()
    |> open("/recover")
    |> fill("input[name=code]", code)
    |> click_button("Sign in with a recovery code")
    |> assert_has("p", text: "Signed in as ada")

    conn
    |> clear_cookies()
    |> open("/recover")
    |> fill("input[name=code]", code)
    |> click_button("Sign in with a recovery code")
    |> assert_has("[role=alert]")

    account = Repo.get_by!(User, username: "ada")
    assert RecoveryCodes.remaining(account) == 11
  end
end
