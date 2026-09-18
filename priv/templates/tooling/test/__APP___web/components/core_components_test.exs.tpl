defmodule __MODULE__Web.CoreComponentsTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  alias __MODULE__Web.CoreComponents

  test "invalid fields use only the error border color" do
    for type <- ["text", "select", "textarea"] do
      html = render_component(&CoreComponents.input/1,
        type: type, id: "name", name: "name", value: "", options: [], errors: ["is invalid"])

      assert html =~ "border-red-600"
      refute html =~ "border-zinc-400"
    end
  end
end
