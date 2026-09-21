defmodule __MODULE__Web.AddressedAccountsTest do
  @moduledoc """
  What the auth screens ask for, and what they say when the answer is refused.

  The library calls the field `username` in both modes, so every sentence about it has to know
  which one this instance means. Telling somebody that a username may hold underscores, when what
  was wanted was an address, sends them nowhere.
  """
  # async: false — these turn the identity mode around.
  use __MODULE__Web.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias __MODULE__.SetupSupport
  alias __MODULE__Web.CeremonyMessages

  defp addressing, do: SetupSupport.put_identity(:email)

  setup %{conn: conn} do
    %{conn: conn |> Plug.Test.init_test_session(%{}) |> SetupSupport.authorize_conn()}
  end

  test "the first account is asked for as an address", %{conn: conn} do
    addressing()
    {:ok, _view, html} = live(conn, ~p"/setup")

    assert html =~ "Email address"
    refute html =~ "your_username"
  end

  test "and as a name otherwise", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/setup")

    assert html =~ "your_username"
    refute html =~ "Email address"
  end

  test "a refusal says what was actually wanted" do
    addressing()

    assert CeremonyMessages.message("invalid_username", nil) =~ "email address"
    assert CeremonyMessages.message("username_taken", nil) =~ "address"
    assert CeremonyMessages.message("username_required", nil) =~ "address"
    assert CeremonyMessages.message("identifier_mismatch", nil) =~ "address"
  end

  test "and says the other thing when an account is named" do
    assert CeremonyMessages.message("invalid_username", nil) =~ "underscores"
    assert CeremonyMessages.message("username_taken", nil) =~ "username"
    assert CeremonyMessages.message("username_required", nil) =~ "username"
    assert CeremonyMessages.message("identifier_mismatch", nil) =~ "username"
  end
end
