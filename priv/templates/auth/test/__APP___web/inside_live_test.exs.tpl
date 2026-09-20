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

  test "manual invitations stop at the per-account hourly limit", %{conn: conn} do
    {:ok, signed} =
      conn
      |> Plug.Test.init_test_session(%{})
      |> __MODULE__.SetupSupport.authorize_conn()
      |> Auth.register(key_attrs(), "ada", %{})

    conn = Plug.Test.init_test_session(build_conn(), get_session(signed))
    {:ok, view, _html} = live(conn, "/")

    for number <- 1..10 do
      view
      |> form("#invitation-form", username: "guest#{number}")
      |> render_submit()
    end

    assert Repo.aggregate(Invitation, :count) == 10

    html = view |> form("#invitation-form", username: "guest11") |> render_submit()

    assert html =~ "Too many invitations. Please try again later."
    assert Repo.aggregate(Invitation, :count) == 10

    german_conn =
      build_conn()
      |> Plug.Test.init_test_session(get_session(signed))
      |> put_req_header("accept-language", "de")

    {:ok, german_view, _html} = live(german_conn, "/")
    german_html = german_view |> form("#invitation-form", username: "guest12") |> render_submit()
    assert german_html =~ "Zu viele Einladungen. Bitte versuche es später erneut."
    assert Repo.aggregate(Invitation, :count) == 10

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
