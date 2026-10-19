defmodule __MODULE__Web.MemberLayoutTest do
  use ExUnit.Case, async: true
  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias __MODULE__Web.Layouts

  @account %{username: "ada"}

  defp page(assigns) do
    assigns = Map.merge(%{flash: %{}, current_account: @account}, assigns)

    ~H"""
    <Layouts.member {assigns}>
      <h1 data-large-title>Page</h1>
    </Layouts.member>
    """
    |> rendered_to_string()
    |> LazyHTML.from_fragment()
  end

  defp columns(selected) do
    assigns = %{flash: %{}, current_account: @account, selected: selected}

    ~H"""
    <Layouts.member
      flash={@flash}
      current_account={@current_account}
      layout={:columns}
      selected={@selected}
      title="Item"
      back={%{to: "/items", label: "Items"}}
      breadcrumb
    >
      <p id="stray">Above the panes</p>
      <:list>Rows</:list>
      <:detail>Detail</:detail>
    </Layouts.member>
    """
    |> rendered_to_string()
    |> LazyHTML.from_fragment()
  end

  defp classes(html, selector), do: html |> LazyHTML.query(selector) |> LazyHTML.attribute("class") |> hd()
  defp texts(html, selector),
    do: html |> LazyHTML.query(selector) |> Enum.map(&(&1 |> LazyHTML.text() |> String.trim()))

  test "the sidebar lists the navigation and marks the page's section" do
    html = page(%{section: :home})

    assert texts(html, "#sidebar a") == ["Home"]
    assert html |> LazyHTML.query("#sidebar a[aria-current=page]") |> Enum.count() == 1
    assert classes(html, "#sidebar") =~ "hidden"
    assert classes(html, "#sidebar") =~ "lg:flex"
  end

  # One place needs no tab bar; a phone reaches it through the wordmark.
  test "the phone's tab bar appears once there are two places" do
    assert page(%{}) |> LazyHTML.query("#main-navigation") |> Enum.empty?()

    navigation = [
      %{section: :home, label: "Home", to: "/", icon: :house},
      %{section: :reports, label: "Reports", to: "/reports", icon: :chart_bar}
    ]

    html = page(%{navigation: navigation, section: :reports})

    assert texts(html, "#main-navigation a") == ["Home", "Reports"]
    assert html |> LazyHTML.query("#main-navigation a[aria-current=page]") |> LazyHTML.text() =~ "Reports"
    assert classes(html, "#main-navigation") =~ "lg:hidden"
  end

  test "a page with a parent leads back on phones and shows a breadcrumb on wide screens" do
    html = page(%{title: "Passkeys", back: %{to: "/account/settings", label: "Settings"}, breadcrumb: true})

    assert html |> LazyHTML.query("#nav-back") |> LazyHTML.attribute("href") == ["/account/settings"]
    assert texts(html, "#nav-title") == ["Passkeys"]
    assert html |> LazyHTML.query("#breadcrumb [aria-current=page]") |> LazyHTML.text() == "Passkeys"

    plain = page(%{title: "Passkeys"})
    assert plain |> LazyHTML.query("#nav-back, #breadcrumb") |> Enum.empty?()
  end

  test "the header shrinks the title once the large heading scrolls away" do
    html = page(%{})

    assert html |> LazyHTML.query("#app-header") |> LazyHTML.attribute("phx-hook") == ["ShrinkTitle"]
    assert html |> LazyHTML.query("[data-large-title]") |> Enum.count() == 1
  end

  test "the account menu reaches the account pages and signs out" do
    html = page(%{})

    # The icon alone says nothing; the name says whose menu it is.
    assert html |> LazyHTML.query("#user-menu summary") |> LazyHTML.attribute("aria-label") == ["Account menu, ada"]
    assert html |> LazyHTML.query("#user-menu a[href='/account/passkeys']") |> Enum.count() == 1
    assert html |> LazyHTML.query("#user-menu a[href='/account/recovery-codes']") |> Enum.count() == 1
    assert html |> LazyHTML.query("#user-menu a[data-method=delete][href='/session']") |> Enum.count() == 1
  end

  # A phone shows one pane at a time; from lg both stand side by side and scroll on their own.
  test "the columns layout shows the list, or the detail once something is selected" do
    list = columns(false)
    assert classes(list, "#list-pane") =~ "lg:overflow-y-auto"
    refute classes(list, "#list-pane") =~ "hidden"
    assert classes(list, "#detail-pane") =~ "hidden lg:block"

    detail = columns(true)
    assert classes(detail, "#list-pane") =~ "hidden lg:block"
    refute classes(detail, "#detail-pane") =~ ~r/(^|\s)hidden(\s|$)/
    assert detail |> LazyHTML.query("#detail-pane") |> LazyHTML.text() =~ "Detail"

    # Nothing renders above the panes, which fill the screen's height from lg.
    assert detail |> LazyHTML.query("#stray") |> Enum.empty?()

    # The list stands beside the detail on wide screens, so no breadcrumb pushes the panes down.
    assert detail |> LazyHTML.query("#breadcrumb") |> Enum.empty?()
    assert detail |> LazyHTML.query("#nav-back") |> LazyHTML.attribute("href") == ["/items"]
  end
end
