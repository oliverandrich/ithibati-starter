defmodule __MODULE__Web.InvitationTest do
  @moduledoc """
  The flow this example exists to show, in a browser.

  Every test here is about a row an instance can hold exactly once — the claim, an invitation that
  is spent by being accepted. Nothing has to clean up between them: the server shares the test's
  sandboxed connection, so each starts from an empty database and rolls back when it ends.
  """
  use __MODULE__Web.PlaywrightCase

  alias __MODULE__.Accounts.Invitation

  # The two preludes the first test walks through with its own assertions, so that the tests about
  # something else can reach their subject in a line.
  defp claim(conn, username) do
    conn
    |> unlock_setup()
    |> fill("input[name=username]", username)
    |> click_button("Create your passkey")
    |> assert_path("/recovery-codes")
    |> assert_has("h1", text: "Save your recovery codes")
  end

  # The link is shown once and never again — the row holds the token's digest — so it is read here
  # or not at all.
  defp invite_link(conn, note) do
    conn
    |> open("/account/invitations")
    |> fill("input[name=note]", note)
    |> click_button("Create a link")
    |> text_of("code")
  end

  defp main_text(conn), do: text_of(conn, "main")

  defp text_of(conn, selector) do
    conn
    |> assert_has(selector)
    |> value_of("() => document.querySelector(#{inspect(selector)}).innerText.trim()")
  end

  # The page opens the invitation only once the hook has pushed the token.
  defp answered(conn), do: conn |> assert_has("[role=alert]") |> main_text()

  test "the first account claims the instance, and everyone after it arrives on a link", %{conn: conn} do
    virtual_authenticator(conn)

    conn
    |> open("/")
    |> assert_has("#setup-code-form")
    |> refute_has("#claim-form")
    |> fill("input[name=setup_code]", "wrong")
    |> click_button("Unlock setup")
    |> assert_has("[role=alert]", text: "That setup code is invalid")
    |> unlock_setup()
    |> fill("input[name=username]", "ada")
    |> click_button("Create your passkey")
    |> assert_path("/recovery-codes")
    |> assert_has("h1", text: "Save your recovery codes")

    link = invite_link(conn, "Grace, from the meetup")
    assert link =~ "/invite#"

    # A fresh session, because an invitation is for somebody who is not signed in — and checked
    # here rather than after the fact: accepting signs you in as the invitee either way, so an
    # assertion further down holds whether or not this line did anything.
    conn
    |> clear_cookies()
    |> open("/")
    |> refute_has("p", text: "Signed in as")

    # The token leaves the address before the socket joins, so neither the join nor the history
    # keeps it. The invitee chooses the name.
    conn
    |> open(link)
    |> assert_has("#invitation-accept-form")

    assert value_of(conn, "() => location.href") =~ ~r{/invite$}

    conn
    |> fill("input[name=username]", "grace")
    |> click_button("Accept with a passkey")
    |> assert_path("/recovery-codes")
    |> assert_has("h1", text: "Save your recovery codes")

    conn
    |> open("/")
    |> assert_has("p", text: "Signed in as grace.")

    assert Repo.get_by(User, username: "grace")
    assert Repo.one(Invitation).accepted_at
  end

  # A used link, an expired one and one nobody ever held are one answer on purpose: anything else
  # tells a guesser which of their guesses was once real.
  test "a spent link and an invented one are answered exactly alike", %{conn: conn} do
    virtual_authenticator(conn)

    claim(conn, "ada")
    link = invite_link(conn, "Grace")

    conn
    |> clear_cookies()
    |> open(link)
    |> fill("input[name=username]", "grace")
    |> click_button("Accept with a passkey")
    |> assert_path("/recovery-codes")
    |> assert_has("h1", text: "Save your recovery codes")

    spent = conn |> clear_cookies() |> open(link) |> answered()
    # Through `/` first, because a change of the fragment alone loads no new page.
    invented = conn |> open("/") |> open("/invite#a-token-nobody-ever-held") |> answered()

    # Word for word, because anything else is a signal.
    assert spent == invented
    assert spent =~ "has been used already, or it has expired"
  end

  # A second link opened in the same tab changes only the fragment, which loads nothing by itself.
  test "another link opened in the same tab opens its own invitation", %{conn: conn} do
    virtual_authenticator(conn)

    claim(conn, "ada")
    [_, token] = conn |> invite_link("Grace") |> String.split("#")

    conn
    |> clear_cookies()
    |> open("/invite#a-token-nobody-ever-held")
    |> assert_has("[role=alert]")
    |> evaluate("window.location.hash = '#{token}'")
    |> assert_has("#invitation-accept-form")
  end

  # Refused before the passkey dialog, so no credential is made for a name that cannot be stored.
  test "a taken name is refused before any passkey is made", %{conn: conn} do
    virtual_authenticator(conn)

    claim(conn, "ada")
    link = invite_link(conn, "Grace")

    conn
    |> clear_cookies()
    |> open(link)
    |> fill("input[name=username]", "ada")
    |> click_button("Accept with a passkey")
    |> assert_has("[role=alert]", text: "That username is taken.")

    refute Repo.one(Invitation).accepted_at
  end

  test "the instance can be claimed once, and the form does not come back", %{conn: conn} do
    virtual_authenticator(conn)

    claim(conn, "ada")

    conn
    |> open("/")
    |> assert_has("p", text: "Signed in as ada.")
    |> refute_has("#claim-form")
  end

  # Headless Chrome may refuse the clipboard, so the page records what it would write. A new link
  # mounts a new button, so the last link's check does not carry over.
  test "the copy button puts each new link on the clipboard", %{conn: conn} do
    virtual_authenticator(conn)

    claim(conn, "ada")
    link = invite_link(conn, "Grace")

    conn
    |> evaluate("""
    Object.defineProperty(navigator, 'clipboard', {configurable: true, value: {
      writeText: async text => { window.copiedText = text }
    }})
    """)
    |> click_button("Copy link")
    |> assert_has("[id^=copy-link-status-]", text: "Link copied.")
    |> assert_has("[phx-hook=CopyText][data-copied]")
    |> evaluate("window.copiedText", fn copied -> assert copied == link end)
    |> fill("input[name=note]", "Ada")
    |> click_button("Create a link")
    |> assert_has("[phx-hook=CopyText]:not([data-copy-text='#{link}'])")
    # Read once, not awaited: the old check clears itself after two seconds.
    |> evaluate(
      "document.querySelector(`[phx-hook=CopyText]:not([data-copy-text='#{link}'])`).hasAttribute('data-copied')",
      fn copied -> refute copied end
    )
    |> click_button("Copy link")
    |> assert_has("[phx-hook=CopyText][data-copied]")
    |> evaluate("window.copiedText", fn copied ->
      assert copied =~ "/invite#"
      refute copied == link
    end)
    |> evaluate("""
    navigator.clipboard.writeText = async () => { throw new Error('permission denied') }
    """)
    |> click_button("Copy link")
    |> assert_has("[id^=copy-link-status-]", text: "Copying was blocked")
  end
end
