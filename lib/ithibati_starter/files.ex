defmodule IthibatiStarter.Files do
  @moduledoc false

  @starter_version Mix.Project.config()[:version]
  # The pinned Ithibati release. The dependency requirement and the generated docs both read it.
  @ithibati_version "0.11.0"

  def ithibati_version, do: @ithibati_version

  def read(igniter, path) do
    igniter = Igniter.include_existing_file(igniter, path)
    {igniter, igniter.rewrite |> Rewrite.source!(path) |> Rewrite.Source.get(:content)}
  end

  def render(text, bindings) do
    text
    |> String.replace("__MODULE__", bindings.module)
    |> String.replace("__APP__", bindings.app)
    |> String.replace("__APP_UPCASE__", String.upcase(bindings.app))
    |> String.replace("__BRAND__", bindings.brand)
    |> String.replace("__STARTER_VERSION__", @starter_version)
    |> String.replace("__ITHIBATI_VERSION__", @ithibati_version)
    |> sort_aliases()
  end

  defp sort_aliases(text) do
    Regex.replace(~r/^((?:[ \t]*alias [^\n]+\n){2,})/m, text, fn block ->
      block
      |> String.trim_trailing("\n")
      |> String.split("\n")
      |> Enum.sort()
      |> Enum.join("\n")
      |> Kernel.<>("\n")
    end)
  end

  def template(name, bindings) do
    :ithibati_starter
    |> :code.priv_dir()
    |> Path.join("templates/#{name}.tpl")
    |> File.read!()
    |> render(bindings)
  end

  def copy_tree(igniter, profile, bindings, opts \\ []) do
    base = Path.join(:code.priv_dir(:ithibati_starter), "templates/#{profile}")

    base
    |> Path.join("**/*.tpl")
    |> Path.wildcard(match_dot: true)
    |> Enum.reduce(igniter, fn path, acc ->
      destination =
        path |> Path.relative_to(base) |> String.trim_trailing(".tpl") |> render(bindings)

      Igniter.create_new_file(acc, destination, path |> File.read!() |> render(bindings), opts)
    end)
  end

  def replace(igniter, path, old, new), do: replace(igniter, path, [{old, new}])

  # Applies the pairs in one update, so a source that is only valid after all of them, such as
  # an opened block and its `end`, is never parsed half done.
  def replace(igniter, path, pairs) do
    Igniter.update_file(igniter, path, fn source ->
      case replace_all(Rewrite.Source.get(source, :content), pairs) do
        {:ok, text} ->
          Rewrite.Source.update(source, :content, text)

        :missing ->
          {:error, "#{path}: expected Phoenix scaffold anchor missing; refusing to guess."}
      end
    end)
  end

  defp replace_all(text, pairs) do
    Enum.reduce_while(pairs, {:ok, text}, fn {old, new}, {:ok, text} ->
      if String.contains?(text, old),
        do: {:cont, {:ok, String.replace(text, old, new)}},
        else: {:halt, :missing}
    end)
  end

  def append(igniter, path, text) do
    Igniter.update_file(igniter, path, fn source ->
      Rewrite.Source.update(source, :content, Rewrite.Source.get(source, :content) <> text)
    end)
  end
end
