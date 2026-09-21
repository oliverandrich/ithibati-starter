defmodule __MODULE__Web.LayoutsTest do
  @moduledoc """
  The one place where the browser is told the same rule as the server.

  A `pattern` attribute that disagrees with `__MODULE__.Identity.format/0` refuses names the
  server would take, or waves through names it will not, and neither failure says anything — so
  the derivation that keeps them in step is pinned rather than trusted.
  """
  # async: false — one test turns the identity mode around.
  use ExUnit.Case, async: false

  alias __MODULE__.Identity
  alias __MODULE__.SetupSupport
  alias __MODULE__Web.Layouts

  # HTML anchors `pattern` implicitly; this is what the browser compiles it to.
  defp as_browser_sees_it do
    Regex.compile!("\\A(?:" <> Layouts.identifier_pattern() <> ")\\z")
  end

  test "the pattern the form carries answers exactly what the library answers" do
    for value <- [
          "alice",
          "a",
          "_",
          "0123456789",
          String.duplicate("a", 30),
          String.duplicate("a", 31),
          "alice.smith",
          "alice-smith",
          "alice smith",
          "Alice",
          "\u0430lice",
          "alice@example.com",
          "",
          "alice\n"
        ] do
      assert Regex.match?(as_browser_sees_it(), value) == Regex.match?(Identity.format(), value),
             "the form and the server disagree about #{inspect(value)}"
    end
  end

  # The guard on the derivation itself: `pattern` is ECMAScript, which has no `\\A`, so a stray
  # anchor would not merely be untidy — the browser would refuse to compile the attribute and stop
  # validating anything at all, silently.
  test "and carries no anchor the browser cannot compile" do
    refute Layouts.identifier_pattern() =~ ~r/\\[Az]/
  end

  # An address gets `type="email"` and the browser's own check. A pattern built from the email
  # grammar would be the disagreement this module exists to prevent, so there is none.
  test "an instance that addresses its accounts carries no pattern at all" do
    SetupSupport.put_identity(:email)

    assert Layouts.identifier_pattern() == nil
  end
end
