defmodule __MODULE__Web.InvitationMailTest do
  use __MODULE__Web.ConnCase
  import Swoosh.TestAssertions

  alias __MODULE__.Accounts.Invitation
  alias __MODULE__.Accounts.User
  alias __MODULE__.InvitationEmail
  alias __MODULE__.Invitations
  alias __MODULE__.Repo
  alias __MODULE__Web.Auth
  alias __MODULE__Web.Endpoint

  setup do
    attrs = %{key_id: :crypto.strong_rand_bytes(16), public_key: :crypto.strong_rand_bytes(64)}
    {:ok, signed} = Auth.register(Plug.Test.init_test_session(build_conn(), %{}), attrs, "ada", %{})
    %{conn: Plug.Test.init_test_session(build_conn(), get_session(signed)), account: Repo.get_by!(User, username: "ada")}
  end

  defp recipient, do: "guest-#{System.unique_integer([:positive])}@example.test"

  test "authenticated form sends a usable invitation without changing the identifier", %{conn: conn} do
    address = recipient()
    html = conn |> get("/") |> html_response(200)
    assert html =~ "mail-invitation-form"
    assert html =~ "invitation[email]"
    conn = post(%{conn | host: "untrusted.example"}, "/account/invitations", %{invitation: %{username: "grace", email: address}})
    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Invitation email sent."
    assert_email_sent(fn email ->
      assert email.to == [{"", address}]
      assert email.subject =~ "__MODULE__"
      assert email.text_body =~ "grace"
      [link] = Regex.run(~r{https?://\S+/invite/[A-Za-z0-9_-]+}, email.text_body)
      assert String.starts_with?(link, Endpoint.url() <> "/invite/")
      refute link =~ "untrusted.example"
      assert build_conn() |> get(URI.parse(link).path) |> html_response(200) =~ "grace"
    end)
    assert Repo.one!(Invitation).username == "grace"
    refute Repo.get_by(User, username: "grace")
  end

  test "anonymous and revoked sessions cannot send", %{conn: conn} do
    params = %{invitation: %{username: "grace", email: recipient()}}
    assert build_conn() |> post("/account/invitations", params) |> redirected_to() == "/login"
    delete(conn, "/account/sessions")
    assert conn |> post("/account/invitations", params) |> redirected_to() == "/login"
    assert Repo.aggregate(Invitation, :count) == 0
    refute_email_sent()
  end

  test "invalid input does not create an invitation or send mail", %{conn: conn} do
    for attrs <- [%{username: "grace", email: "not-an-email"}, %{username: "!", email: recipient()}] do
      failed = post(conn, "/account/invitations", %{invitation: attrs})
      assert Phoenix.Flash.get(failed.assigns.flash, :error)
    end
    assert Repo.aggregate(Invitation, :count) == 0
    refute_email_sent()
  end

  test "mail content follows the browser locale", %{conn: conn} do
    address = recipient()
    conn |> put_req_header("accept-language", "de-DE") |> post("/account/invitations", %{invitation: %{username: "grace", email: address}})
    assert_email_sent(fn email ->
      assert email.subject == "Deine Einladung zu __MODULE__"
      assert email.text_body =~ "Passkey"
      assert email.text_body =~ "Benutzername: grace"
    end)
  end

  test "HTML content escapes the supplied link" do
    {:ok, content} = InvitationEmail.content("https://example.test/?a=1&b=2", %{username: "grace"})
    assert content.html =~ ~s(href="https://example.test/?a=1&amp;b=2")
  end

  test "delivery errors remain errors and leave the committed invitation valid" do
    deliver = fn _recipient, _content -> {:error, :unavailable} end
    assert {:error, {:delivery, :unavailable}} = Invitations.send_email(%{"username" => "grace", "email" => recipient()}, deliver)
    invitation = Repo.one!(Invitation)
    assert invitation.username == "grace"
    assert is_nil(invitation.accepted_at)
    refute_email_sent()
  end

  test "recipient limit rejects repeated sends", %{conn: conn} do
    address = recipient()
    for i <- 1..3 do
      sent = post(conn, "/account/invitations", %{invitation: %{username: "guest#{i}", email: address}})
      assert Phoenix.Flash.get(sent.assigns.flash, :info)
    end
    blocked = post(conn, "/account/invitations", %{invitation: %{username: "guest4", email: String.upcase(address)}})
    assert Phoenix.Flash.get(blocked.assigns.flash, :error) == "Too many invitations. Please try again later."
    assert Repo.aggregate(Invitation, :count) == 3
  end
end
