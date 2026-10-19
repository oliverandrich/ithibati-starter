defmodule __MODULE__Web.TailwindTest do
  use __MODULE__Web.PlaywrightCase

  test "styles follow system changes and ignore an old stored theme", %{conn: conn} do
    conn
    |> color_scheme("light")
    |> open("/")
    |> evaluate("localStorage.setItem('phx:theme', 'dark')")
    |> open("/")
    |> refute_has("[data-phx-theme]")

    # Chrome's serialisation of an oklch colour varies by version, so the light value is read
    # from the page and compared with itself rather than written out here.
    light = background(conn)
    refute light == "rgba(0, 0, 0, 0)"

    assert value_of(conn, "() => getComputedStyle(document.querySelector('#setup-code-form button')).display") ==
             "inline-flex"

    color_scheme(conn, "dark")
    assert value_of(conn, "() => getComputedStyle(document.body).colorScheme") == "dark"
    refute background(conn) in [light, "rgba(0, 0, 0, 0)"]

    color_scheme(conn, "light")
    assert background(conn) == light
  end

  defp background(conn), do: value_of(conn, "() => getComputedStyle(document.body).backgroundColor")
end
