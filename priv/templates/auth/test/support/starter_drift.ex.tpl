defmodule __MODULE__.StarterDrift do
  @moduledoc """
  Compares this application's Elixir files with the Ithibati Starter templates they came from.

  The templates come from the starter version in `mix.lock`, or the path `mix.exs` names.
  Elixir files compare as syntax trees, so formatting, comments, docs and alias order do not count.
  HEEx inside `~H` compares without whitespace, because the formatter reflows it.
  """

  # Assembled from parts, because the installer replaces the whole placeholders in this file too.
  @module_placeholder "__" <> "MODULE" <> "__"
  @app_placeholder "__" <> "APP" <> "__"
  @upcase_placeholder "__" <> "APP_UPCASE" <> "__"
  @brand_placeholder "__" <> "BRAND" <> "__"

  @doc "Returns the starter's template directories, or `[]` when the starter is not fetched."
  def roots do
    case starter_path() do
      nil ->
        []

      path ->
        ["auth", "tooling"]
        |> Enum.map(&Path.join([path, "priv", "templates", &1]))
        |> Enum.filter(&File.dir?/1)
    end
  end

  # Declared in mix.exs `only: :dev`, so the test environment does not load it. Its location is
  # the `path:` option, or `deps/` for a git or Hex dependency.
  defp starter_path do
    case List.keyfind(Mix.Project.config()[:deps], :ithibati_starter, 0) do
      nil ->
        nil

      dep ->
        opts = dep |> Tuple.to_list() |> List.last()
        path = if is_list(opts), do: opts[:path]
        Path.expand(path || Path.join(Mix.Project.deps_path(), "ithibati_starter"))
    end
  end

  @doc """
  Returns `{template, local}` for every Elixir template with a counterpart here. `local` is
  relative to the project root.

  Found by wildcard, so a template added in a later starter version is compared as well.
  """
  def pairs(roots, app) do
    for root <- roots,
        template <- Path.wildcard(Path.join(root, "**/*.{ex,exs}.tpl"), match_dot: true),
        local = local_path(template, root, app),
        File.regular?(local),
        do: {template, local}
  end

  defp local_path(template, root, app) do
    template
    |> Path.relative_to(root)
    |> String.replace_suffix(".tpl", "")
    |> String.replace(@app_placeholder, app)
  end

  @doc """
  Returns the template rendered with this application's names and brand colour.

  The same substitution as the starter's `IthibatiStarter.Files.render/2`, which the test
  environment does not load.
  """
  def render(text, app, module, brand) do
    text
    |> String.replace(@module_placeholder, module)
    |> String.replace(@upcase_placeholder, String.upcase(app))
    |> String.replace(@app_placeholder, app)
    |> String.replace(@brand_placeholder, brand)
  end

  @doc "Returns the brand colour the installer recorded in `.ithibati-starter`."
  def brand do
    with {:ok, profile} <- File.read(".ithibati-starter"),
         [_, brand] <- Regex.run(~r/^brand=(\w+)$/m, profile),
         do: brand,
         else: (_ -> "violet")
  end

  @doc "Returns the code of an Elixir source as a syntax tree without positions, comments and docs."
  def code(source) do
    source
    |> Code.string_to_quoted!()
    |> Macro.prewalk(&normalize/1)
  end

  defp normalize({:@, _meta, [{doc, _, [_text]}]}) when doc in [:moduledoc, :doc, :typedoc],
    do: {:@, [], [{doc, [], [:prose]}]}

  defp normalize({:sigil_H, _meta, [{:<<>>, _, parts}, modifiers]}),
    do: {:sigil_H, [], [{:<<>>, [], Enum.map(parts, &squeeze/1)}, modifiers]}

  # The installer sorts each run of aliases, and the order depends on the application's name.
  defp normalize({:__block__, _meta, exprs}) do
    exprs =
      exprs
      |> Enum.chunk_by(&match?({:alias, _, _}, &1))
      |> Enum.flat_map(fn
        [{:alias, _, _} | _] = aliases -> Enum.sort_by(aliases, &Macro.to_string/1)
        other -> other
      end)

    {:__block__, [], exprs}
  end

  defp normalize({name, meta, args}) when is_list(meta), do: {name, [], args}
  defp normalize(other), do: other

  defp squeeze(part) when is_binary(part), do: String.replace(part, ~r/\s+/, "")
  defp squeeze(part), do: part
end
