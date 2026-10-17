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
end
