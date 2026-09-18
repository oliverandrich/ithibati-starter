defmodule IthibatiStarter.Files do
  @moduledoc false

  def read(igniter, path) do
    igniter = Igniter.include_existing_file(igniter, path)
    {igniter, igniter.rewrite |> Rewrite.source!(path) |> Rewrite.Source.get(:content)}
  end

  def render(text, bindings) do
    text
    |> String.replace("__MODULE__", bindings.module)
    |> String.replace("__APP__", bindings.app)
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

  def replace(igniter, path, old, new) do
    Igniter.update_file(igniter, path, fn source ->
      text = Rewrite.Source.get(source, :content)

      if String.contains?(text, old) do
        Rewrite.Source.update(source, :content, String.replace(text, old, new))
      else
        {:error, "#{path}: expected Phoenix scaffold anchor missing; refusing to guess."}
      end
    end)
  end

  def append(igniter, path, text) do
    Igniter.update_file(igniter, path, fn source ->
      Rewrite.Source.update(source, :content, Rewrite.Source.get(source, :content) <> text)
    end)
  end
end
