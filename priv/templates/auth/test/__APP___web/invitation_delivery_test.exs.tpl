defmodule __MODULE__Web.FailingAdapter do
  @moduledoc false
  @behaviour Swoosh.Adapter

  @impl true
  def deliver(_email, _config), do: {:error, :econnrefused}

  @impl true
  def validate_config(_config), do: :ok
end

defmodule __MODULE__Web.RaisingAdapter do
  @moduledoc false
  @behaviour Swoosh.Adapter

  @impl true
  def deliver(_email, _config), do: raise(ArgumentError, "a value gen_smtp cannot use")

  @impl true
  def validate_config(_config), do: :ok
end

defmodule __MODULE__Web.InvitationDeliveryTest do
  @moduledoc """
  What making an invitation does, in each of the two modes.

  Named, the link is shown and nothing is sent. Addressed, it is sent to the identifier the
  invitation carries, which is what proves the address belongs to whoever answers.

  The invitation is written before any of this and outlives a delivery that failed. The link is
  the only copy there will ever be, so it stays on the screen either way.
  """
  # async: false — these turn the identity mode around.
  use __MODULE__Web.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  alias __MODULE__.SetupSupport
  alias __MODULE__Web.Auth

  defp key_attrs,
    do: %{key_id: :crypto.strong_rand_bytes(16), public_key: :crypto.strong_rand_bytes(64)}

  defp signed_in(conn, identifier) do
    {:ok, signed} =
      conn
      |> Plug.Test.init_test_session(%{})
      |> SetupSupport.authorize_conn()
      |> Auth.register(key_attrs(), identifier, %{})

    Plug.Test.init_test_session(build_conn(), get_session(signed))
  end

  defp addressing, do: SetupSupport.put_identity(:email)

  defp invite(conn, identifier) do
    {:ok, view, _html} = live(conn, "/")
    view |> form("#invitation-form", username: identifier) |> render_submit()
    render(view)
  end

  test "a named guest is given a link and nothing is sent", %{conn: conn} do
    html = conn |> signed_in("ada") |> invite("grace_hopper")

    assert html =~ "/invite/"
    refute_email_sent()
  end

  test "an addressed guest is sent the link, and still shown it", %{conn: conn} do
    addressing()
    html = conn |> signed_in("ada@example.test") |> invite("grace@example.test")

    assert [link] = Regex.run(~r{https?://\S+/invite/[A-Za-z0-9_-]+}, html)

    assert_email_sent(fn email ->
      assert email.to == [{"", "grace@example.test"}]
      assert email.text_body =~ link
    end)
  end

  # The invitation is already written by the time anything is sent, so a mail server that is down
  # is something the sender is told about rather than something that takes the invitation away.
  test "a delivery that fails says so and leaves the link standing", %{conn: conn} do
    addressing()
    SetupSupport.put_env(:__APP__, __MODULE__.Mailer, adapter: __MODULE__Web.FailingAdapter)

    html = conn |> signed_in("ada@example.test") |> invite("grace@example.test")

    assert html =~ "/invite/"
    assert html =~ "could not be sent"
  end

  # Swoosh raises rather than answers for a configuration its adapter refuses, and gen_smtp does
  # the same for a value it cannot use. The invitation is written by then and its token lives in
  # this process alone, so a raise would take the only copy of the link with it.
  test "a delivery that raises loses neither the invitation nor the link", %{conn: conn} do
    addressing()
    SetupSupport.put_env(:__APP__, __MODULE__.Mailer, adapter: __MODULE__Web.RaisingAdapter)

    html = conn |> signed_in("ada@example.test") |> invite("grace@example.test")

    assert html =~ "/invite/"
    assert html =~ "could not be sent"
  end

  test "the form asks for an address when that is what an account is", %{conn: conn} do
    addressing()
    {:ok, _view, html} = live(signed_in(conn, "ada@example.test"), "/")

    assert html =~ "Their email address"
    refute html =~ "Their username"
  end

  test "and for a name when it is not", %{conn: conn} do
    {:ok, _view, html} = live(signed_in(conn, "ada"), "/")

    assert html =~ "Their username"
    refute html =~ "Their email address"
  end
end
