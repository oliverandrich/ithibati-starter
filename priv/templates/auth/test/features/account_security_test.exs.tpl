defmodule __MODULE__Web.AccountSecurityFeatureTest do
  use __MODULE__Web.FeatureCase

  alias Ithibati.Identity.Passkeys
  alias Ithibati.Identity.RecoveryCodes

  feature "a member manages passkeys and replaces recovery codes from the settings", %{session: session} do
    first = virtual_authenticator(session)

    session
    |> unlock_setup()
    |> fill_in(css("input[name=username]"), with: "ada")
    |> click(button("Create your passkey"))
    |> landed_on("/recovery-codes")
    |> open("/")
    |> click(css("#user-menu summary"))
    |> click(link("Settings"))
    |> landed_on("/account/settings")
    |> click(css("#settings-account a", text: "Passkeys"))
    |> landed_on("/account/passkeys")
    |> connected()

    session
    |> click(link("Confirm your identity to add a passkey"))
    |> landed_on("/account/verify")
    |> connected()
    |> click(button("Confirm with a passkey"))
    |> landed_on("/account/passkeys")
    |> connected()

    # A different authenticator models a second device. The first device's existing
    # credential is correctly excluded from enrollment by Ithibati.
    {:ok, _} = Wallaby.HTTPClient.request(:post, "#{session.url}/chromium/send_command_and_get_result", %{
      cmd: "WebAuthn.removeVirtualAuthenticator", params: %{authenticatorId: first}
    })
    virtual_authenticator(session)
    session
    |> fill_in(css("#add-passkey-form input[name=label]"), with: "Phone")
    |> click(button("Add a passkey"))
    |> through_navigation(css("article input[value=Phone]"))

    account = Repo.get_by!(User, username: "ada")
    assert length(Passkeys.list_keys(account)) == 2
    phone = Enum.find(Passkeys.list_keys(account), &(&1.label == "Phone"))
    session
    |> fill_in(css("#key-#{phone.id} input[name=label]"), with: "Work phone")
    |> click(css("#key-#{phone.id} button", text: "Save name"))
    |> through_navigation(css("input[value='Work phone']"))
    |> open("/account/recovery-codes")
    |> click(css("input[name=confirm]"))
    |> click(button("Generate new recovery codes"))
    |> landed_on("/recovery-codes")
    |> assert_has(button("Copy recovery codes"))
    |> assert_has(css("h1", text: "Save your recovery codes"))
  end

  feature "German security pages work on a narrow screen", %{session: session} do
    language(session, "de")
    virtual_authenticator(session)
    viewport(session, 390, 844, true)
    session
    |> unlock_setup()
    |> fill_in(css("input[name=username]"), with: "ada")
    |> click(button("Erstelle deinen Passkey"))
    |> landed_on("/recovery-codes")
    |> open("/")
    |> click(css("#user-menu summary"))
    |> take_screenshot(name: "account-menu-mobile", log: false)
    |> click(link("Einstellungen"))
    |> landed_on("/account/settings")
    |> take_screenshot(name: "account-settings-mobile", log: false)
    |> click(css("#settings-account a", text: "Passkeys"))
    |> landed_on("/account/passkeys")
    |> connected()
    |> assert_has(link("Bestätige deine Identität, um einen Passkey hinzuzufügen"))
    |> take_screenshot(name: "account-passkeys-mobile", log: false)
    |> open("/account/recovery-codes")
    |> assert_has(css("p", text: "Du hast 12 unbenutzte Wiederherstellungscodes."))
    |> take_screenshot(name: "account-recovery-mobile", log: false)
    # A long back label and a long title share the bar once the heading scrolls away.
    |> scroll_past_heading()
    |> execute_script(
      """
      const back = document.querySelector('#nav-back').getBoundingClientRect()
      const text = document.createRange()
      text.selectNodeContents(document.querySelector('#nav-title'))
      return back.right <= text.getBoundingClientRect().left
      """,
      fn clear -> assert clear end
    )
  end

  feature "a recovery code confirms identity when the passkey is unavailable", %{session: session} do
    virtual_authenticator(session)
    session |> unlock_setup() |> fill_in(css("input[name=username]"), with: "ada") |> click(button("Create your passkey")) |> landed_on("/recovery-codes")
    account = Repo.get_by!(User, username: "ada")
    [code | _] = RecoveryCodes.regenerate(account)
    session
    |> open("/account/recovery-codes")
    |> click(link("Confirm your identity to generate new codes"))
    |> landed_on("/account/verify")
    |> connected()
    |> click(css("summary", text: "Use a recovery code instead"))
    |> fill_in(css("input[name=code]"), with: code)
    |> click(button("Confirm with a recovery code"))
    |> landed_on("/account/recovery-codes")
    |> connected()
    |> assert_has(button("Generate new recovery codes"))
  end
end
