defmodule __MODULE__Web.InvitationMailFeatureTest do
  use __MODULE__Web.FeatureCase
  import Swoosh.TestAssertions

  setup :set_swoosh_global

  feature "a guest accepts an invitation sent from the email form", %{session: session} do
    virtual_authenticator(session)
    session
    |> unlock_setup()
    |> fill_in(css("input[name=username]"), with: "ada")
    |> click(button("Create your passkey"))
    |> landed_on("/recovery-codes")
    |> open("/")
    |> fill_in(css("input[name='invitation[username]']"), with: "grace")
    |> fill_in(css("input[name='invitation[email]']"), with: "guest-#{System.unique_integer([:positive])}@example.test")
    |> click(button("Send invitation"))
    |> through_navigation(css("#flash-info", text: "Invitation email sent."))

    assert_receive {:email, email}, 5000
    [link] = Regex.run(~r{https?://\S+/invite/[A-Za-z0-9_-]+}, email.text_body)
    session
    |> clear_cookies()
    |> open(link)
    |> assert_has(css("p", text: "The account will be called"))
    |> click(button("Accept with a passkey"))
    |> landed_on("/recovery-codes")
    |> open("/")
    |> assert_has(css("p", text: "Signed in as grace."))
    assert Repo.get_by!(User, username: "grace")
  end
end
