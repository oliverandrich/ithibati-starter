defmodule __MODULE__Web.BrowserPoolTest do
  @moduledoc """
  The browser features share one Chrome session. A feature must not see what the one before it
  left: cookies, storage or the page.
  """
  use __MODULE__Web.FeatureCase

  alias __MODULE__Web.BrowserPool

  feature "the shared session comes back empty", %{session: session} do
    session
    |> open("/login")
    |> execute_script("""
    localStorage.setItem("left", "behind")
    sessionStorage.setItem("left", "behind")
    document.cookie = "left=behind; path=/"
    """)

    again = BrowserPool.checkout()
    assert again.id == session.id

    again
    |> visit("/login")
    |> execute_script(
      "return [localStorage.getItem('left'), sessionStorage.getItem('left'), document.cookie]",
      &send(self(), {:left, &1})
    )

    assert_received {:left, [nil, nil, cookies]}
    refute cookies =~ "left=behind"
  end

  # Wallaby documents a count as well as a list of capabilities.
  @sessions 2
  feature "a feature that asks for two sessions gets two of its own", %{sessions: [one, two]} do
    refute one.id == two.id
  end
end
