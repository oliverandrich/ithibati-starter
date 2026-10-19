defmodule __MODULE__Web.InvitationTest do
  @moduledoc """
  The flow this example exists to show, in a browser.

  Every test here is about a row an instance can hold exactly once — the claim, an invitation that
  is spent by being accepted. Nothing has to clean up between them: Wallaby shares the test's
  sandboxed connection, so each starts from an empty database and rolls back when it ends.
  """
  use __MODULE__Web.FeatureCase

  alias __MODULE__.Accounts.Invitation

  # The two preludes the first test walks through with its own assertions, so that the tests about
  # something else can reach their subject in a line.
  defp claim(session, username) do
    session
    |> unlock_setup()
    |> fill_in(css("input[name=username]"), with: username)
    |> click(button("Create your passkey"))
    |> landed_on("/recovery-codes")
    |> assert_has(css("h1", text: "Save your recovery codes"))
  end

  # The link is shown once and never again — the row holds the token's digest — so it is read here
  # or not at all.
  defp invite_link(session, note) do
    session
    |> open("/account/invitations")
    |> fill_in(css("input[name=note]"), with: note)
    |> click(button("Create a link"))
    |> find(css("code"))
    |> Element.text()
    |> String.trim()
  end

  defp main_text(session), do: session |> find(css("main")) |> Element.text()

  # The page opens the invitation only once the hook has pushed the token.
  defp answered(session), do: session |> assert_has(css("[role=alert]")) |> main_text()

  feature "the first account claims the instance, and everyone after it arrives on a link", %{
    session: session
  } do
    virtual_authenticator(session)

    session
    |> open("/")
    |> assert_has(css("#setup-code-form"))
    |> refute_has(css("#claim-form"))
    |> fill_in(css("input[name=setup_code]"), with: "wrong")
    |> click(button("Unlock setup"))
    |> through_navigation(css("[role=alert]", text: "That setup code is invalid"))
    |> unlock_setup()
    |> fill_in(css("input[name=username]"), with: "ada")
    |> click(button("Create your passkey"))
    |> landed_on("/recovery-codes")
    |> assert_has(css("h1", text: "Save your recovery codes"))

    link = invite_link(session, "Grace, from the meetup")
    assert link =~ "/invite#"

    # A fresh session, because an invitation is for somebody who is not signed in — and checked
    # here rather than after the fact: accepting signs you in as the invitee either way, so an
    # assertion further down holds whether or not this line did anything.
    session
    |> clear_cookies()
    |> open("/")
    |> refute_has(css("p", text: "Signed in as"))

    # The token leaves the address before the socket joins, so neither the join nor the history
    # keeps it. The invitee chooses the name.
    session
    |> open(link)
    |> assert_has(css("#invitation-accept-form"))

    assert current_url(session) =~ ~r{/invite$}

    session
    |> fill_in(css("input[name=username]"), with: "grace")
    |> click(button("Accept with a passkey"))
    |> landed_on("/recovery-codes")
    |> assert_has(css("h1", text: "Save your recovery codes"))

    session
    |> open("/")
    |> assert_has(css("p", text: "Signed in as grace."))

    assert Repo.get_by(User, username: "grace")
    assert Repo.one(Invitation).accepted_at
  end

  # A used link, an expired one and one nobody ever held are one answer on purpose: anything else
  # tells a guesser which of their guesses was once real.
  feature "a spent link and an invented one are answered exactly alike", %{session: session} do
    virtual_authenticator(session)

    claim(session, "ada")
    link = invite_link(session, "Grace")

    session
    |> clear_cookies()
    |> open(link)
    |> fill_in(css("input[name=username]"), with: "grace")
    |> click(button("Accept with a passkey"))
    |> landed_on("/recovery-codes")
    |> assert_has(css("h1", text: "Save your recovery codes"))

    spent = session |> clear_cookies() |> open(link) |> answered()
    invented = session |> open("/invite#a-token-nobody-ever-held") |> answered()

    # Word for word, because anything else is a signal.
    assert spent == invented
    assert spent =~ "has been used already, or it has expired"
  end

  # A second link opened in the same tab changes only the fragment, which loads nothing by itself.
  feature "another link opened in the same tab opens its own invitation", %{session: session} do
    virtual_authenticator(session)

    claim(session, "ada")
    [_, token] = session |> invite_link("Grace") |> String.split("#")

    session
    |> clear_cookies()
    |> open("/invite#a-token-nobody-ever-held")
    |> assert_has(css("[role=alert]"))
    |> execute_script("window.location.hash = '#{token}'")
    |> assert_has(css("#invitation-accept-form"))
  end

  # Refused before the passkey dialog, so no credential is made for a name that cannot be stored.
  feature "a taken name is refused before any passkey is made", %{session: session} do
    virtual_authenticator(session)

    claim(session, "ada")
    link = invite_link(session, "Grace")

    session
    |> clear_cookies()
    |> open(link)
    |> fill_in(css("input[name=username]"), with: "ada")
    |> click(button("Accept with a passkey"))
    |> assert_has(css("[role=alert]", text: "That username is taken."))

    refute Repo.one(Invitation).accepted_at
  end

  feature "the instance can be claimed once, and the form does not come back", %{session: session} do
    virtual_authenticator(session)

    claim(session, "ada")

    session
    |> open("/")
    |> assert_has(css("p", text: "Signed in as ada."))
    |> refute_has(css("#claim-form"))
  end

  # Headless Chrome may refuse the clipboard, so the page records what it would write. A new link
  # mounts a new button, so the last link's check does not carry over.
  feature "the copy button puts each new link on the clipboard", %{session: session} do
    virtual_authenticator(session)

    claim(session, "ada")
    link = invite_link(session, "Grace")

    session
    |> execute_script("""
    Object.defineProperty(navigator, 'clipboard', {configurable: true, value: {
      writeText: async text => { window.copiedText = text }
    }})
    """)
    |> click(button("Copy link"))
    |> assert_has(css("[id^=copy-link-status-]", text: "Link copied."))
    |> assert_has(css("[phx-hook=CopyText][data-copied]"))
    |> execute_script("return window.copiedText", fn copied -> assert copied == link end)
    |> fill_in(css("input[name=note]"), with: "Ada")
    |> click(button("Create a link"))
    |> assert_has(css("[phx-hook=CopyText]:not([data-copy-text='#{link}'])"))
    # Read once, not awaited: the old check clears itself after two seconds.
    |> execute_script(
      "return document.querySelector(`[phx-hook=CopyText]:not([data-copy-text='#{link}'])`).hasAttribute('data-copied')",
      fn copied -> refute copied end
    )
    |> click(button("Copy link"))
    |> assert_has(css("[phx-hook=CopyText][data-copied]"))
    |> execute_script("return window.copiedText", fn copied ->
      assert copied =~ "/invite#"
      refute copied == link
    end)
    |> execute_script("""
    navigator.clipboard.writeText = async () => { throw new Error('permission denied') }
    """)
    |> click(button("Copy link"))
    |> assert_has(css("[id^=copy-link-status-]", text: "Copying was blocked"))
  end
end
