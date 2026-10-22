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

  # The dialog stays in the page; `data-show` tells its hook to open or close it.
  test "a confirmation dialog asks one question and names its two answers" do
    dialog = fn show ->
      assigns = %{show: show}

      ~H"""
      <CoreComponents.confirm_dialog name="remove" show={@show} title="Remove ada?" confirm_label="Remove" variant="danger">
        It cannot be undone.
      </CoreComponents.confirm_dialog>
      """
      |> rendered_to_string()
      |> LazyHTML.from_fragment()
    end

    html = dialog.(true)
    assert html |> LazyHTML.query("dialog#remove-confirm[data-show]") |> LazyHTML.attribute("aria-labelledby") == ["remove-heading"]
    assert html |> LazyHTML.query("dialog[open]") |> Enum.empty?()
    assert html |> LazyHTML.query("#remove-heading") |> LazyHTML.text() == "Remove ada?"
    assert html |> LazyHTML.query("#confirm-remove") |> LazyHTML.attribute("phx-click") == ["confirm_remove"]
    assert html |> LazyHTML.query("#cancel-remove") |> LazyHTML.attribute("phx-click") == ["cancel_remove"]

    assert dialog.(false) |> LazyHTML.query("dialog#remove-confirm:not([data-show])") |> Enum.count() == 1
  end

  # The status line sits outside the button, and a patch must not clear its sentence.
  test "a copy field shows its value beside a button that copies it, and has its own status line" do
    assigns = %{}

    html =
      ~H(<CoreComponents.copy_field id="code-1" value="abc-123" label="Copy code" copied="Code copied." />)
      |> rendered_to_string()
      |> LazyHTML.from_fragment()

    assert html |> LazyHTML.query("code") |> LazyHTML.text() == "abc-123"

    button = LazyHTML.query(html, "button#code-1-copy[phx-hook=CopyText][type=button]")
    assert LazyHTML.attribute(button, "data-copy-text") == ["abc-123"]
    assert LazyHTML.attribute(button, "data-copy-status") == ["code-1-status"]
    assert LazyHTML.attribute(button, "data-copy-success") == ["Code copied."]
    assert LazyHTML.attribute(button, "aria-label") == ["Copy code"]
    assert [_blocked] = LazyHTML.attribute(button, "data-copy-error")

    assert html |> LazyHTML.query("#code-1-status[role=status][phx-update=ignore]") |> Enum.count() == 1
  end

  test "a copy field without labels names its button generically" do
    assigns = %{}
    html = rendered_to_string(~H(<CoreComponents.copy_field id="token" value="t" />))

    assert html =~ ~s(aria-label="Copy")
    assert html =~ ~s(data-copy-success="Copied.")
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
