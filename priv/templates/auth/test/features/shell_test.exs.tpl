defmodule __MODULE__Web.ShellTest do
  use __MODULE__Web.FeatureCase

  feature "the member shell is a sidebar on wide screens and a top bar on phones", %{session: session} do
    virtual_authenticator(session)
    viewport(session, 1280, 900, false)

    session
    |> unlock_setup()
    |> fill_in(css("input[name=username]"), with: "ada")
    |> click(button("Create your passkey"))
    |> landed_on("/recovery-codes")
    |> open("/")
    |> connected()
    |> assert_has(css("#sidebar-home[aria-current=page]"))
    |> execute_script("return getComputedStyle(document.querySelector('#sidebar')).display", fn display ->
      assert display == "flex"
    end)
    |> take_screenshot(name: "shell-desktop", log: false)

    # The same page narrows to a phone, so the hook must renew the margin from the header's height.
    session
    |> viewport(390, 844, true)
    |> execute_script("return getComputedStyle(document.querySelector('#sidebar')).display", fn display ->
      assert display == "none"
    end)
    |> execute_script("return getComputedStyle(document.querySelector('#app-header')).position", fn position ->
      assert position == "sticky"
    end)
    |> take_screenshot(name: "shell-phone", log: false)
    # Content long enough to scroll the large heading under the top bar.
    |> execute_script("""
    document.querySelector('#main-content').insertAdjacentHTML('beforeend', '<div style="height: 3000px"></div>')
    window.scrollTo(0, 1500)
    """)
    |> assert_has(css("#app-header[data-shrunk]"))
    # The observer reports in a later frame, so the check waits for the attribute to go.
    |> execute_script("window.scrollTo(0, 0)")
    |> assert_has(css("#app-header:not([data-shrunk])"))
  end
end
