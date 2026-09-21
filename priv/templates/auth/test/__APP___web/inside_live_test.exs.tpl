defmodule __MODULE__Web.InsideLiveTest do
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

  # A day rather than an hour, because what this guards against is not a burst: it is an account
  # somebody else is holding, spending the operator's mail credentials at a steady drip.
  test "manual invitations stop at the per-account daily budget", %{conn: conn} do
    {:ok, signed} =
      conn
      |> Plug.Test.init_test_session(%{})
      |> __MODULE__.SetupSupport.authorize_conn()
      |> Auth.register(key_attrs(), "ada", %{})

    conn = Plug.Test.init_test_session(build_conn(), get_session(signed))
    {:ok, view, _html} = live(conn, "/")

    for number <- 1..20 do
      view
      |> form("#invitation-form", username: "guest#{number}")
      |> render_submit()
    end

    assert Repo.aggregate(Invitation, :count) == 20

    html = view |> form("#invitation-form", username: "guest21") |> render_submit()

    # Hours, because nobody reads tens of thousands of seconds as a waiting time.
    assert html =~ "Too many invitations. Try again in 24 hours."
    assert Repo.aggregate(Invitation, :count) == 20

    german_conn =
      build_conn()
      |> Plug.Test.init_test_session(get_session(signed))
      |> put_req_header("accept-language", "de")

    {:ok, german_view, _html} = live(german_conn, "/")
    german_html = german_view |> form("#invitation-form", username: "guest22") |> render_submit()
    assert german_html =~ "Zu viele Einladungen. Versuche es in 24 Stunden erneut."
    assert Repo.aggregate(Invitation, :count) == 20

    another = Repo.insert!(Invitation.changeset(%Invitation{}, %{username: "grace"}))

    {:ok, second_signed} =
      Auth.register(Plug.Test.init_test_session(build_conn(), %{}), key_attrs(), "grace", %{
        "token" => another.token
      })

    second_conn = Plug.Test.init_test_session(build_conn(), get_session(second_signed))
    {:ok, second_view, _html} = live(second_conn, "/")
    second_view |> form("#invitation-form", username: "fresh_guest") |> render_submit()

    assert Repo.get_by!(Invitation, username: "fresh_guest")
  end
end
