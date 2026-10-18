defmodule IthibatiStarter.License do
  @moduledoc false
  alias Igniter.Project.Config
  alias IthibatiStarter.Files

  @spdx %{"mit" => "MIT", "agpl" => "AGPL-3.0-or-later"}

  # Directories that hold only the application's code, and its own files at the root.
  @roots ~w(lib test config priv/repo assets/js assets/css rel)
  @root_files ~w(mix.exs .formatter.exs .credo.exs .igniter.exs)
  # File types with a known comment syntax. Release start commands are shell scripts without one.
  @extensions ~w(.ex .exs .heex .js .mjs .css)
  @scripts "rel/overlays/bin/"

  @doc "Returns the reason the license options are refused, or nil."
  def issue(license, source_url) do
    cond do
      not Map.has_key?(@spdx, license) ->
        "Unknown license #{inspect(license)}; use mit or agpl."

      license == "agpl" and source_url == nil ->
        "AGPL needs --source-url, the address where users get this application's source code."

      license == "agpl" and not absolute_http?(source_url) ->
        "--source-url must be an absolute http or https URL: #{inspect(source_url)}."

      license != "agpl" and source_url != nil ->
        "--source-url applies only with --license agpl."

      true ->
        nil
    end
  end

  def install(igniter, b, opts) do
    license = Keyword.fetch!(opts, :license)
    holder = Keyword.fetch!(opts, :copyright)
    year = Date.utc_today().year

    license_text =
      "licenses/#{license}"
      |> Files.template(b)
      |> String.replace("__YEAR__", to_string(year))
      |> String.replace("__HOLDER__", holder)

    igniter
    |> Igniter.create_new_file("LICENSE", license_text)
    |> Files.append("README.md", """

    ## License

    Copyright (c) #{year} #{holder}

    This application is licensed under `#{@spdx[license]}`. See [LICENSE](LICENSE) for the full text.
    """)
    |> source_url(b, license, opts[:source_url])
  end

  @doc "The paths the generated LicenseMarkerTest checks."
  def paths, do: @roots ++ @root_files

  @doc "The file types the generated LicenseMarkerTest checks."
  def extensions, do: @extensions

  @doc """
  Puts an SPDX license identifier at the top of every source file of the application.

  It covers the scaffold's files and every file the installer has written before it.
  """
  def mark(igniter, license) do
    marker = "SPDX-License-Identifier: #{@spdx[license]}"

    igniter
    |> candidates()
    |> Enum.reduce(igniter, fn path, acc ->
      Igniter.update_file(acc, path, fn source ->
        Rewrite.Source.update(
          source,
          :content,
          mark_text(Rewrite.Source.get(source, :content), path, marker)
        )
      end)
    end)
  end

  defp candidates(igniter) do
    existing =
      if igniter.assigns[:test_mode?],
        do: Map.keys(igniter.assigns.test_files),
        else:
          Enum.flat_map(@roots, &Path.wildcard(Path.join(&1, "**/*"), match_dot: true)) ++
            @root_files

    created = igniter.rewrite |> Rewrite.sources() |> Enum.map(& &1.path)

    (existing ++ created)
    |> Enum.uniq()
    |> Enum.filter(&licensed?/1)
    |> Enum.reject(&(&1 in igniter.rms or File.dir?(&1)))
    |> Enum.filter(&Igniter.exists?(igniter, &1))
  end

  defp licensed?(path) do
    (String.starts_with?(path, Enum.map(@roots, &(&1 <> "/"))) or path in @root_files) and
      not String.contains?(path, "/vendor/") and
      (Path.extname(path) in @extensions or String.starts_with?(path, @scripts))
  end

  defp mark_text(text, path, marker) do
    head = text |> String.split("\n", parts: 6) |> Enum.take(5) |> Enum.join("\n")
    ext = Path.extname(path)

    cond do
      String.contains?(head, "SPDX-License-Identifier") ->
        text

      ext == ".heex" ->
        after_first(text, ~r/\A<!doctype/i, "<%!-- #{marker} --%>")

      ext in ~w(.js .mjs) ->
        "// #{marker}\n\n" <> text

      ext == ".css" ->
        "/* #{marker} */\n\n" <> text

      ext in ~w(.ex .exs) or String.starts_with?(text, "#!") ->
        after_first(text, ~r/\A#!/, "# #{marker}")

      # A start command without a shebang is not a script to mark.
      true ->
        text
    end
  end

  # A doctype or a shebang must stay on the first line.
  defp after_first(text, first_line, line) do
    if text =~ first_line do
      case String.split(text, "\n", parts: 2) do
        [first, rest] -> first <> "\n" <> line <> "\n" <> rest
        [first] -> first <> "\n" <> line <> "\n"
      end
    else
      line <> "\n\n" <> text
    end
  end

  # AGPL section 13: the application offers its source to the users it serves over a network.
  defp source_url(igniter, b, "agpl", url),
    do: Config.configure(igniter, "config.exs", String.to_atom(b.app), [:source_url], url)

  defp source_url(igniter, _b, _license, _url), do: igniter

  defp absolute_http?(url) do
    match?(
      %URI{scheme: scheme, host: host} when scheme in ~w(http https) and host not in [nil, ""],
      URI.parse(url)
    )
  end
end
