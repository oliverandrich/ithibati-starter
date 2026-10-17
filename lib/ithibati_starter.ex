defmodule IthibatiStarter do
  @moduledoc """
  Opinionated Phoenix 1.8/PostgreSQL starter with invitation-only Ithibati 0.8.1.

  Call `install/2` from an Igniter task. This installer targets fresh applications;
  it is not an upgrade tool. Reapplying the same profile preserves all user edits.
  """
  alias Igniter.Project.Application, as: ProjectApplication
  alias Igniter.Project.Module, as: ProjectModule
  alias IthibatiStarter.Auth
  alias IthibatiStarter.Files
  alias IthibatiStarter.Tooling

  @marker ".ithibati-starter"

  # Tailwind's chromatic palettes. A grey brand would be indistinguishable from the ink.
  @brands ~w(red orange amber yellow lime green emerald teal cyan sky blue indigo violet purple fuchsia pink rose)

  @doc "Plans an installation. Options: `:without_beans`, `:brand`."
  def install(igniter, opts \\ []) do
    brand = Keyword.get(opts, :brand, "violet")
    profile = "0.7.0\nauth=true\nbeans=#{!opts[:without_beans]}\nbrand=#{brand}\n"

    cond do
      brand not in @brands ->
        Igniter.add_issue(
          igniter,
          "Unknown brand colour #{inspect(brand)}; use one of: #{Enum.join(@brands, ", ")}."
        )

      Igniter.exists?(igniter, @marker) ->
        reapply(igniter, profile)

      true ->
        install_new(igniter, opts, profile, brand)
    end
  end

  defp reapply(igniter, profile) do
    {igniter, current} = Files.read(igniter, @marker)

    if current == profile,
      do: igniter,
      else:
        Igniter.add_issue(
          igniter,
          "Installed starter version/profile differs; automatic conversion is unsupported. " <>
            "Installed: #{inspect(current)}. Requested: #{inspect(profile)}."
        )
  end

  defp install_new(igniter, opts, profile, brand) do
    app = ProjectApplication.app_name(igniter)
    module = ProjectModule.module_name_prefix(igniter)
    bindings = %{app: to_string(app), module: inspect(module), brand: brand}
    router = "lib/#{app}_web/router.ex"

    if Igniter.exists?(igniter, router) and Igniter.exists?(igniter, "lib/#{app}/repo.ex") do
      {igniter, repo} = Files.read(igniter, "lib/#{app}/repo.ex")

      {igniter, config} = Files.read(igniter, "config/config.exs")
      {igniter, router_source} = Files.read(igniter, router)

      cond do
        not fresh_router?(router_source, bindings) ->
          Igniter.add_issue(
            igniter,
            "The router differs from the fresh Phoenix 1.8.14 scaffold with a mailer; " <>
              "refusing to replace it."
          )

        Enum.any?(
          [
            "mise.toml",
            ".credo.exs",
            "CONTRIBUTING.md",
            ".github/workflows/ci.yml",
            ".github/workflows/audit.yml",
            ".github/dependabot.yml"
          ],
          &Igniter.exists?(igniter, &1)
        ) ->
          Igniter.add_issue(
            igniter,
            "Refusing to replace existing tooling; use a fresh Phoenix project."
          )

        String.contains?(config, "binary_id: true") ->
          Igniter.add_issue(igniter, "The auth profile does not support binary_id yet.")

        String.contains?(repo, "Ecto.Adapters.Postgres") ->
          igniter
          |> Tooling.install(bindings, opts)
          |> Auth.install(bindings)
          |> Igniter.create_new_file(@marker, profile)
          |> Igniter.add_task("format", [])
          |> Igniter.add_notice(
            "Starter installed. Review CONTRIBUTING.md, then run mise trust, mise install and mise run setup."
          )

        true ->
          Igniter.add_issue(
            igniter,
            "Ithibati Starter currently requires Phoenix with PostgreSQL."
          )
      end
    else
      Igniter.add_issue(
        igniter,
        "Start with a fresh Phoenix application with Ecto, HTML, LiveView and PostgreSQL."
      )
    end
  end

  # Every generated application ships the mailer, so the scaffold this replaces is the one
  # Phoenix writes with it: the mailbox preview is part of a fresh router rather than a variant.
  defp fresh_router?(source, bindings) do
    canonical(source) == canonical(Files.template("fragments/phoenix_router", bindings))
  end

  defp canonical(source), do: source |> Code.string_to_quoted!() |> Macro.to_string()
end
