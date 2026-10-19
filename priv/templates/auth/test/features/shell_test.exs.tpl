defmodule __MODULE__Web.ShellTest do
  use __MODULE__Web.PlaywrightCase

  test "the member shell is a sidebar on wide screens and a top bar on phones", %{conn: conn} do
    virtual_authenticator(conn)
    resize(conn, 1280, 900)

    conn
    |> unlock_setup()
    |> fill("input[name=username]", "ada")
    |> click_button("Create your passkey")
    |> assert_path("/recovery-codes")
    |> open("/")
    |> connected()
    |> assert_has("#sidebar-home[aria-current=page]")
    |> evaluate("getComputedStyle(document.querySelector('#sidebar')).display", fn display ->
      assert display == "flex"
    end)
    |> screenshot("shell-desktop.png")

    # The same page narrows to a phone, so the hook must renew the margin from the header's height.
    conn
    |> resize(390, 844)
    |> evaluate("getComputedStyle(document.querySelector('#sidebar')).display", fn display ->
      assert display == "none"
    end)
    |> evaluate("getComputedStyle(document.querySelector('#app-header')).position", fn position ->
      assert position == "sticky"
    end)
    |> screenshot("shell-phone.png")
    |> scroll_past_heading()
    # The observer reports in a later frame, so the check waits for the attribute to go.
    |> evaluate("window.scrollTo(0, 0)")
    |> assert_has("#app-header:not([data-shrunk])")
  end
end
