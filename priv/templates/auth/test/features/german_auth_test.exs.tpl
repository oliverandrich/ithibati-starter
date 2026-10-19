defmodule __MODULE__Web.GermanAuthTest do
  use __MODULE__Web.PlaywrightCase

  @tag browser_context_opts: [locale: "de-DE"]
  test "German survives setup, clipboard, sign-out and live recovery navigation", %{conn: conn} do
    virtual_authenticator(conn)

    conn
    |> unlock_setup()
    |> assert_has("html[lang=de]")
    |> fill("input[name=username]", "ada")
    |> click_button("Erstelle deinen Passkey")
    |> assert_path("/recovery-codes")
    |> assert_has("h1", text: "Speichere deine Wiederherstellungscodes")
    |> evaluate("Object.defineProperty(navigator, 'clipboard', {configurable: true, value: {writeText: async () => {}}})")
    |> click_button("Wiederherstellungscodes kopieren")
    |> assert_has("#copy-status", text: "Wiederherstellungscodes kopiert.")
    |> click_link("Codes gespeichert. Weiter")
    |> assert_path("/")
    |> assert_has("p", text: "Angemeldet als ada.")
    |> connected()
    |> click("#user-menu summary")
    |> click_link("Abmelden")
    |> assert_path("/login")
    |> click_link("Passkey verloren? Wiederherstellungscode verwenden")
    |> fill("input[name=code]", "invalid-code")
    |> click_button("Mit Wiederherstellungscode anmelden")
    |> assert_has("[role=alert]", text: "Dieser Wiederherstellungscode ist ungültig.")
    |> click_link("Zurück zur Passkey-Anmeldung")
    |> assert_has("button", text: "Mit einem Passkey anmelden")
  end
end
