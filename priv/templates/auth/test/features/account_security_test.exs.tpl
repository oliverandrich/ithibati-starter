defmodule __MODULE__Web.AccountSecurityFeatureTest do
  use __MODULE__Web.PlaywrightCase

  alias Ithibati.Identity.Passkeys
  alias Ithibati.Identity.RecoveryCodes

  test "a member manages passkeys and replaces recovery codes from the settings", %{conn: conn} do
    first = virtual_authenticator(conn)

    conn
    |> unlock_setup()
    |> fill("input[name=username]", "ada")
    |> click_button("Create your passkey")
    |> assert_path("/recovery-codes")
    |> open("/")
    |> click("#user-menu summary")
    |> click_link("Settings")
    |> assert_path("/account/settings")
    |> click("#settings-account a", "Passkeys")
    |> assert_path("/account/passkeys")
    |> connected()

    conn
    |> click_link("Confirm your identity to add a passkey")
    |> assert_path("/account/verify")
    |> connected()
    |> click_button("Confirm with a passkey")
    |> assert_path("/account/passkeys")
    |> connected()

    # A different authenticator models a second device. The first device's existing
    # credential is correctly excluded from enrollment by Ithibati.
    conn |> remove_authenticator(first) |> virtual_authenticator()
    conn
    |> fill("#add-passkey-form input[name=label]", "Phone")
    |> click_button("Add a passkey")
    |> assert_has("article input[value=Phone]")

    account = Repo.get_by!(User, username: "ada")
    assert length(Passkeys.list_keys(account)) == 2
    phone = Enum.find(Passkeys.list_keys(account), &(&1.label == "Phone"))
    conn
    |> fill("#key-#{phone.id} input[name=label]", "Work phone")
    |> click("#key-#{phone.id} button", "Save name")
    |> assert_has("input[value='Work phone']")
    |> open("/account/recovery-codes")
    |> click("input[name=confirm]")
    |> click_button("Generate new recovery codes")
    |> assert_path("/recovery-codes")
    |> assert_has("button", text: "Copy recovery codes")
    |> assert_has("h1", text: "Save your recovery codes")
  end

  @tag browser_context_opts: [{:locale, "de"} | phone(390, 844)]
  test "German security pages work on a narrow screen", %{conn: conn} do
    virtual_authenticator(conn)
    conn
    |> unlock_setup()
    |> fill("input[name=username]", "ada")
    |> click_button("Erstelle deinen Passkey")
    |> assert_path("/recovery-codes")
    |> open("/")
    |> click("#user-menu summary")
    |> screenshot("account-menu-mobile.png")
    |> click_link("Einstellungen")
    |> assert_path("/account/settings")
    |> screenshot("account-settings-mobile.png")
    |> click("#settings-account a", "Passkeys")
    |> assert_path("/account/passkeys")
    |> connected()
    |> assert_has("a", text: "Bestätige deine Identität, um einen Passkey hinzuzufügen")
    |> screenshot("account-passkeys-mobile.png")
    |> open("/account/recovery-codes")
    |> assert_has("p", text: "Du hast 12 unbenutzte Wiederherstellungscodes.")
    |> screenshot("account-recovery-mobile.png")
    # A long back label and a long title share the bar once the heading scrolls away.
    |> scroll_past_heading()
    |> evaluate(
      """
      () => {
      const back = document.querySelector('#nav-back').getBoundingClientRect()
      const text = document.createRange()
      text.selectNodeContents(document.querySelector('#nav-title'))
      return back.right <= text.getBoundingClientRect().left
      }
      """,
      [is_function: true],
      fn clear -> assert clear end
    )
  end

  test "a recovery code confirms identity when the passkey is unavailable", %{conn: conn} do
    virtual_authenticator(conn)
    conn |> unlock_setup() |> fill("input[name=username]", "ada") |> click_button("Create your passkey") |> assert_path("/recovery-codes")
    account = Repo.get_by!(User, username: "ada")
    [code | _] = RecoveryCodes.regenerate(account)
    conn
    |> open("/account/recovery-codes")
    |> click_link("Confirm your identity to generate new codes")
    |> assert_path("/account/verify")
    |> connected()
    |> click("summary", "Use a recovery code instead")
    |> fill("input[name=code]", code)
    |> click_button("Confirm with a recovery code")
    |> assert_path("/account/recovery-codes")
    |> connected()
    |> assert_has("button", text: "Generate new recovery codes")
  end
end
