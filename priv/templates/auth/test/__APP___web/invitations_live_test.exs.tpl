defmodule __MODULE__Web.InvitationsLiveTest do
  use __MODULE__Web.ConnCase

  import Phoenix.LiveViewTest

  alias __MODULE__.Accounts.Invitation
  alias __MODULE__.Repo
  alias __MODULE__Web.Auth

  defp key_attrs do
    %{
      key_id: :crypto.strong_rand_bytes(16),
      public_key: :crypto.strong_rand_bytes(64)
    }
  end

  # The first account, signed in and holding a session — every test here starts from one.
  defp signed_in(conn, username) do
    {:ok, signed} =
      conn
      |> Plug.Test.init_test_session(%{})
      |> __MODULE__.SetupSupport.authorize_conn()
      |> Auth.register(key_attrs(), username, %{})

    Plug.Test.init_test_session(build_conn(), get_session(signed))
  end

  # Before a link is redeemed, anybody here has a say over who joins. The page has to show it.
  test "the page lists what is outstanding, by whom, and takes one back", %{conn: conn} do
    {:ok, view, _html} = live(signed_in(conn, "ada"), "/account/invitations")

    view |> form("#invitation-form", note: "Grace, from the meetup") |> render_submit()

    assert render(view) =~ "/invite#"

    # Named, the invitee chooses the name; the note is only for whoever manages invitations.
    invitation = Repo.one(Invitation)
    assert invitation.username == nil
    assert invitation.note == "Grace, from the meetup"

    assert has_element?(view, "#invitation-#{invitation.id}", "Grace, from the meetup")
    assert render(view) =~ "ada"

    # The empty sentence first, then the absence: `assert_has` style waiting is what makes the
    # refutation mean anything, because a refutation alone passes before the patch arrives.
    html =
      view
      |> element(~s(#invitation-#{invitation.id} button[phx-click="withdraw"]))
      |> render_click()

    assert html =~ "Nothing is waiting to be accepted."
    refute has_element?(view, "#invitation-#{invitation.id}")
    refute Repo.one(Invitation)
  end

  test "an invitation from a removed account names a former member", %{conn: conn} do
    gone = Repo.insert!(%__MODULE__.Accounts.User{username: "gone"})
    {:ok, invitation} = __MODULE__.Invitations.open(gone, %{"note" => "Grace"})
    Repo.delete!(gone)

    {:ok, view, _html} = live(signed_in(conn, "ada"), "/account/invitations")
    assert has_element?(view, "#invitation-#{invitation.id}", "Invited by a former member")
  end

  # The link is long, so a button beside it copies it. The hook reads the link from the button.
  test "a new link has a copy button with its own status line", %{conn: conn} do
    {:ok, view, _html} = live(signed_in(conn, "ada"), "/account/invitations")

    html = view |> form("#invitation-form", note: "Grace") |> render_submit()

    [link] = Regex.run(~r{https?://[^\s<"]+/invite#[A-Za-z0-9_-]+}, html)
    button = "button[phx-hook=CopyText][aria-label='Copy link']"
    assert has_element?(view, "#{button}[data-copy-text='#{link}']")

    [_, status] = Regex.run(~r{data-copy-status="([^"]+)"}, html)
    assert has_element?(view, "##{status}[role=status][phx-update=ignore]")
  end

  # The list shows the note and nothing else identifies an open invitation, so one without a note
  # would be a row nobody can tell apart.
  test "a named invitation needs a note", %{conn: conn} do
    {:ok, view, _html} = live(signed_in(conn, "ada"), "/account/invitations")

    assert view |> form("#invitation-form", note: " ") |> render_submit() =~ "Note can&#39;t be blank."
    refute Repo.one(Invitation)
  end

  # The id comes off the wire and nothing upstream says it is a number. Handed to `Repo.get/2`
  # raw it raises `Ecto.Query.CastError`, which takes the LiveView down rather than answering
  # whoever pressed the button.
  test "an id that is not one is answered, not raised at", %{conn: conn} do
    {:ok, view, _html} = live(signed_in(conn, "ada"), "/account/invitations")

    assert render_click(view, "withdraw", %{"id" => "not-an-id"}) =~ "no longer there"
  end

  # A day rather than an hour, because what this guards against is not a burst: it is an account
  # somebody else is holding, spending the operator's mail credentials at a steady drip.
  test "manual invitations stop at the per-account daily budget", %{conn: conn} do
    account = signed_in(conn, "ada")
    {:ok, view, _html} = live(account, "/account/invitations")

    for number <- 1..20 do
      view
      |> form("#invitation-form", note: "guest#{number}")
      |> render_submit()
    end

    assert Repo.aggregate(Invitation, :count) == 20

    html = view |> form("#invitation-form", note: "guest21") |> render_submit()

    # Hours, because nobody reads tens of thousands of seconds as a waiting time.
    assert html =~ "Too many invitations. Try again in 24 hours."
    assert Repo.aggregate(Invitation, :count) == 20

    german_conn =
      build_conn()
      |> Plug.Test.init_test_session(get_session(account))
      |> put_req_header("accept-language", "de")

    {:ok, german_view, _html} = live(german_conn, "/account/invitations")
    german_html = german_view |> form("#invitation-form", note: "guest22") |> render_submit()
    assert german_html =~ "Zu viele Einladungen. Versuche es in 24 Stunden erneut."
    assert Repo.aggregate(Invitation, :count) == 20

    another = Repo.insert!(Invitation.changeset(%Invitation{}, %{username: "grace"}))

    {:ok, second_signed} =
      Auth.register(Plug.Test.init_test_session(build_conn(), %{}), key_attrs(), "grace", %{
        "token" => another.token
      })

    second_conn = Plug.Test.init_test_session(build_conn(), get_session(second_signed))
    {:ok, second_view, _html} = live(second_conn, "/account/invitations")
    second_view |> form("#invitation-form", note: "fresh_guest") |> render_submit()

    assert Repo.get_by!(Invitation, note: "fresh_guest")
  end
end
