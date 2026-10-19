defmodule __MODULE__Web.CoreComponentsTest do
  use ExUnit.Case, async: true
  import Phoenix.Component, only: [sigil_H: 2]
  import Phoenix.LiveViewTest

  alias __MODULE__Web.CoreComponents

  test "invalid fields use only the error border color" do
    for type <- ["text", "select", "textarea"] do
      html = render_component(&CoreComponents.input/1,
        type: type, id: "name", name: "name", value: "", options: [], errors: ["is invalid"])

      assert html =~ "border-danger"
      refute html =~ "border-edge"
    end
  end

  test "an error alert is announced at once, an info alert politely" do
    assigns = %{}
    error = rendered_to_string(~H"<CoreComponents.alert>Failed</CoreComponents.alert>")
    info = rendered_to_string(~H"<CoreComponents.alert kind={:info}>Saved</CoreComponents.alert>")

    assert error =~ ~s(role="alert")
    assert error =~ "border-danger"
    assert info =~ ~s(role="status")
    refute info =~ "border-danger"
  end

  test "a card renders as the element it is given and keeps the caller's classes" do
    assigns = %{}
    html = rendered_to_string(~H(<CoreComponents.card tag="ul" id="codes" class="p-4">a</CoreComponents.card>))

    assert html =~ "<ul"
    assert html =~ ~s(id="codes")
    assert html =~ "ring-line"
    assert html =~ "p-4"
  end

  test "a group of links names its nav by its heading, and a group link leads on with a detail" do
    assigns = %{}

    html =
      ~H"""
      <CoreComponents.group id="security" heading="Security" tag="nav">
        <CoreComponents.group_link to="/account/passkeys" detail={2}>Passkeys</CoreComponents.group_link>
      </CoreComponents.group>
      """
      |> rendered_to_string()
      |> LazyHTML.from_fragment()

    # One landmark per group, named by its heading.
    assert html |> LazyHTML.query("nav#security") |> LazyHTML.attribute("aria-labelledby") == ["security-heading"]
    assert html |> LazyHTML.query("#security nav, #security section") |> Enum.empty?()
    assert html |> LazyHTML.query("#security .ring-line") |> Enum.count() == 1
    assert html |> LazyHTML.query("#security-heading") |> LazyHTML.text() =~ "Security"

    link = LazyHTML.query(html, "nav a[href='/account/passkeys']")
    assert LazyHTML.text(link) =~ "Passkeys"
    assert link |> LazyHTML.query("span.text-muted") |> LazyHTML.text() == "2"
  end

  test "a group of rows names its section, and a group without a heading names nothing" do
    assigns = %{}
    named = rendered_to_string(~H(<CoreComponents.group id="rows" heading="Rows">Row</CoreComponents.group>))
    plain = rendered_to_string(~H(<CoreComponents.group id="plain">Rows</CoreComponents.group>))

    assert named |> LazyHTML.from_fragment() |> LazyHTML.query("section#rows") |> LazyHTML.attribute("aria-labelledby") ==
             ["rows-heading"]
    refute plain =~ "aria-labelledby"
    refute plain =~ "<h2"
  end
end
