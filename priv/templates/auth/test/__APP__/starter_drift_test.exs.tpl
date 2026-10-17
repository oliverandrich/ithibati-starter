defmodule __MODULE__.StarterDriftTest do
  @moduledoc """
  Every generated Elixir file still matches the starter template it came from, in code.

  A fix in the starter reaches this application only when somebody copies it. After
  `mix deps.update ithibati_starter`, this test names the files the new version changed.
  A file this application has taken over goes in `@owned`; the starter's changes to it are then
  this application's to follow or not.
  """
  use ExUnit.Case, async: true

  alias __MODULE__.StarterDrift

  @app "__APP__"
  @module "__MODULE__"

  # Paths in this application, for example "lib/__APP___web/live/inside_live.ex".
  @owned []

  setup_all do
    roots =
      case StarterDrift.roots() do
        [] -> flunk("ithibati_starter is not fetched. Run `mix deps.get`, or remove this test.")
        roots -> roots
      end

    brand = StarterDrift.brand()

    # This file is generated as well, and its @owned list is this application's to fill.
    compared =
      for {template, local} <- StarterDrift.pairs(roots, @app),
          Path.expand(local) != __ENV__.file,
          do: {local, same?(template, local, brand)}

    {:ok, compared: compared}
  end

  test "every generated file matches its template, except those this application owns", ctx do
    drifted = for {local, false} <- ctx.compared, local not in @owned, do: local

    assert drifted == [], """
    These differ in code from the starter's templates:

    #{Enum.map_join(drifted, "\n", &("  " <> &1))}

    Take the starter's version, or add the file to @owned.
    """
  end

  test "a file listed as owned still differs from its template", ctx do
    unchanged = for {local, true} <- ctx.compared, local in @owned, do: local

    assert unchanged == [], """
    These are in @owned and match the starter again. Remove them from @owned:

    #{Enum.map_join(unchanged, "\n", &("  " <> &1))}
    """
  end

  test "docs, comments, layout and alias order do not count; code and markup do" do
    base = """
    defmodule Sample do
      @moduledoc "One wording."
      alias B.Two
      alias A.One
      # A comment.
      def render(assigns), do: ~H"<p>markup</p>"
    end
    """

    reworded = """
    defmodule Sample do
      @moduledoc "Another wording."
      alias A.One
      alias B.Two

      def render(assigns) do
        ~H"<p>
          markup
        </p>"
      end
    end
    """

    assert StarterDrift.code(base) == StarterDrift.code(reworded)
    refute StarterDrift.code(base) == StarterDrift.code(String.replace(base, "<p>", "<div>"))
    refute StarterDrift.code(base) == StarterDrift.code(String.replace(base, "assigns), do", "_assigns), do"))
  end

  defp same?(template, local, brand) do
    theirs =
      template |> File.read!() |> StarterDrift.render(@app, @module, brand) |> StarterDrift.code()

    theirs == local |> File.read!() |> StarterDrift.code()
  end
end
