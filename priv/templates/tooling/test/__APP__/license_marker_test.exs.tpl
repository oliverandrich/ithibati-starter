defmodule __MODULE__.LicenseMarkerTest do
  @moduledoc """
  Every source file states the application's license, so a copied file keeps its terms.

  `mix.exs` names the license. Every directory in `@paths` holds only this application's code,
  so every file of a type in `@extensions` is checked, and every start command under
  `rel/overlays/bin`. Third-party code under `vendor/` keeps its own terms.
  """
  use ExUnit.Case, async: true

  @paths ~w(lib test config priv/repo assets/js assets/css rel mix.exs .formatter.exs .credo.exs .igniter.exs)
  @extensions ~w(.ex .exs .heex .js .mjs .css)

  test "every source file states the application's license" do
    for path <- @paths do
      assert File.exists?(path), "#{path} is checked but no longer exists; update @paths"
    end

    identifier =
      case Regex.run(~r/SPDX-License-Identifier: (\S+)/, head("mix.exs"), capture: :all_but_first) do
        [identifier] -> identifier
        nil -> flunk("mix.exs names no SPDX-License-Identifier in its first five lines")
      end

    marker = "SPDX-License-Identifier: #{identifier}"
    missing = for path <- files(), not String.contains?(head(path), marker), do: path

    assert missing == [], "Add #{marker} to the first five lines of:\n" <> Enum.join(missing, "\n")
  end

  defp files do
    @paths
    |> Enum.flat_map(fn path ->
      if File.dir?(path), do: Path.wildcard(Path.join(path, "**/*"), match_dot: true), else: [path]
    end)
    |> Enum.filter(&File.regular?/1)
    |> Enum.reject(&String.contains?(&1, "/vendor/"))
    |> Enum.filter(&(Path.extname(&1) in @extensions or script?(&1)))
  end

  defp script?(path),
    do: String.starts_with?(path, "rel/overlays/bin/") and String.starts_with?(head(path), "#!")

  defp head(path), do: path |> File.stream!() |> Enum.take(5) |> Enum.join()
end
