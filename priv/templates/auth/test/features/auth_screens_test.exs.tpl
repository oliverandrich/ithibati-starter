defmodule __MODULE__Web.AuthScreensTest do
  use __MODULE__Web.PlaywrightCase

  test "setup, copy codes, home, login and recovery form a complete flow", %{conn: conn} do
    virtual_authenticator(conn)

    conn
    |> unlock_setup()
    |> assert_has("#claim-form")
    |> refute_has("input[name=email]")
    |> fill("input[name=username]", "ada")
    |> click_button("Create your passkey")
    |> assert_path("/recovery-codes")
    |> evaluate("""
    Object.defineProperty(navigator, 'clipboard', {configurable: true, value: {
      writeText: async text => { window.copiedCodes = text }
    }})
    """)
    |> click_button("Copy recovery codes")
    |> assert_has("#copy-status", text: "Recovery codes copied.")
    |> evaluate("""
    window.copiedCodes === Array.from(document.querySelectorAll('#recovery-codes li'), el => el.textContent.trim()).join('\\n')
    """, fn matches -> assert matches end)
    |> evaluate("""
    navigator.clipboard.writeText = async () => { throw new Error('permission denied') }
    """)
    |> click_button("Copy recovery codes")
    |> assert_has("#copy-status", text: "Copying was blocked")
    |> click_link("I've saved my codes. Continue")
    |> assert_path("/")
    |> assert_has("h1", text: "Welcome home")
    |> open("/recovery-codes")
    |> assert_path("/")
    |> connected()
    |> click("#user-menu summary")
    |> click_link("Sign out")
    |> assert_path("/login")
    |> refute_has("#recovery-form")
    |> click_link("Lost your passkey? Use a recovery code")
    |> assert_has("#recovery-form")
    |> refute_has("button", text: "Sign in with a passkey")
    |> click_link("Back to passkey sign-in")
    |> assert_has("button", text: "Sign in with a passkey")
    |> click_button("Sign in with a passkey")
    |> assert_path("/")
    |> assert_has("p", text: "Signed in as ada.")
  end
end
