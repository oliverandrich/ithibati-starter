defmodule IthibatiStarter do
  @moduledoc """
  Opinionated Phoenix 1.8/PostgreSQL starter with invitation-only Ithibati 0.4.0.

  Call `install/2` from an Igniter task. This installer targets fresh applications;
  it is not an upgrade tool. Reapplying the same profile preserves all user edits.
  """
  alias Igniter.Project.Application, as: ProjectApplication
  alias Igniter.Project.Module, as: ProjectModule
  alias IthibatiStarter.Auth
  alias IthibatiStarter.Files
  alias IthibatiStarter.Tooling

  @marker ".ithibati-starter"

  @doc "Plans an installation. Options: `:without_ithibati` and `:without_beans`."
  def install(igniter, opts \\ []) do
    profile = "0.1.0\nauth=#{!opts[:without_ithibati]}\nbeans=#{!opts[:without_beans]}\n"

    if Igniter.exists?(igniter, @marker) do
      {igniter, current} = Files.read(igniter, @marker)

      if current == profile,
        do: igniter,
        else:
          Igniter.add_issue(
            igniter,
            "Installed starter version/profile differs; automatic conversion is unsupported."
          )
    else
      install_new(igniter, opts, profile)
    end
  end

  defp install_new(igniter, opts, profile) do
    app = ProjectApplication.app_name(igniter)
    module = ProjectModule.module_name_prefix(igniter)
    bindings = %{app: to_string(app), module: inspect(module)}
    router = "lib/#{app}_web/router.ex"

    if Igniter.exists?(igniter, router) and Igniter.exists?(igniter, "lib/#{app}/repo.ex") do
      {igniter, repo} = Files.read(igniter, "lib/#{app}/repo.ex")

      {igniter, config} = Files.read(igniter, "config/config.exs")
      {igniter, router_source} = Files.read(igniter, router)

      cond do
        canonical(router_source) !=
            canonical(Files.template("fragments/phoenix_router", bindings)) ->
          Igniter.add_issue(
            igniter,
            "The router differs from the fresh Phoenix 1.8.14 scaffold; refusing to replace it."
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

        !opts[:without_ithibati] and String.contains?(config, "binary_id: true") ->
          Igniter.add_issue(igniter, "The auth profile does not support binary_id yet.")

        String.contains?(repo, "Ecto.Adapters.Postgres") ->
          igniter
          |> Tooling.install(bindings, opts)
          |> maybe_auth(bindings, opts)
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

  defp canonical(source), do: source |> Code.string_to_quoted!() |> Macro.to_string()

  defp maybe_auth(igniter, bindings, opts) do
    if opts[:without_ithibati], do: igniter, else: Auth.install(igniter, bindings)
  end
end
