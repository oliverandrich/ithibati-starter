defmodule IthibatiStarter.Tooling do
  @moduledoc false
  alias Igniter.Project.Config
  alias Igniter.Project.Deps
  alias Igniter.Project.IgniterConfig
  alias Igniter.Project.MixProject
  alias IthibatiStarter.Files

  @deps [
    {:lucide_icons, "~> 2.4.0"},
    {:credo, "~> 1.7.19", only: [:dev, :test], runtime: false},
    {:ex_slop, "~> 0.4.4", only: [:dev, :test], runtime: false},
    {:jump_credo_checks, "~> 0.5.0", only: [:dev, :test], runtime: false},
    {:excellent_migrations, "~> 0.1.10", only: [:dev, :test], runtime: false},
    {:sobelow, "~> 0.15.0", only: [:dev, :test], runtime: false},
    {:mix_audit, "~> 2.1.5", only: [:dev, :test], runtime: false},
    {:tidewave, "~> 0.9.0", only: :dev}
  ]

  def install(igniter, bindings, opts) do
    igniter = Enum.reduce(@deps, igniter, &Deps.add_dep(&2, &1, yes?: true))

    igniter
    |> IgniterConfig.dont_move_file_pattern(~r/^(lib|test)\//)
    |> Deps.remove_dep(:daisyui)
    |> Deps.remove_dep(:heroicons)
    |> Igniter.rm("assets/vendor/heroicons.js")
    |> Files.copy_tree("tooling", bindings, on_exists: :overwrite)
    |> MixProject.update(:project, [:elixir], fn _ -> {:ok, {:code, inspect("~> 1.20")}} end)
    |> MixProject.update(:cli, [:preferred_envs, :precommit], fn _ -> {:ok, {:code, :test}} end)
    |> MixProject.update(:project, [:aliases, :precommit], fn _ -> {:ok, {:code, gate(opts)}} end)
    |> Config.configure("config.exs", :tailwind, [:version], "4.3.3")
    |> Config.configure("config.exs", String.to_atom(bindings.app), [:locales], ["en", "de"])
    |> Config.configure(
      "config.exs",
      String.to_atom(bindings.app),
      [Module.concat([bindings.module <> "Web", Gettext]), :default_locale],
      "en"
    )
    |> Files.replace(
      "lib/#{bindings.app}_web/router.ex",
      "plug :fetch_live_flash",
      "plug :fetch_live_flash\n    plug #{bindings.module}Web.Locale"
    )
    |> Files.replace(
      "lib/#{bindings.app}_web/router.ex",
      "  pipeline :browser do",
      "  scope \"/\", #{bindings.module}Web do\n    get \"/health\", HealthController, :show\n  end\n\n  pipeline :browser do"
    )
    |> database_env()
    |> Files.replace("lib/#{bindings.app}_web/endpoint.ex", "  if code_reloading? do", """
      if Application.compile_env(:#{bindings.app}, :dev_routes, false) do
        plug Tidewave
      end

      if code_reloading? do
    """)
    |> Files.replace("lib/#{bindings.app}_web/router.ex", "plug :put_secure_browser_headers", """
    plug :put_secure_browser_headers, %{
      "content-security-policy" => "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; object-src 'none'; base-uri 'self'; frame-ancestors 'self'; form-action 'self'"
    }
    """)
    |> Files.replace(
      "lib/#{bindings.app}_web/router.ex",
      "  scope \"/\", #{bindings.module}Web do\n    pipe_through :browser\n\n    get \"/\", PageController, :home\n  end",
      "  live_session :default, on_mount: [{#{bindings.module}Web.Locale, :set}] do\n    scope \"/\", #{bindings.module}Web do\n      pipe_through :browser\n      get \"/\", PageController, :home\n    end\n  end"
    )
    |> tidy_scaffold(bindings)
    |> maybe_beans(bindings, opts)
    |> Files.append(".gitignore", "\n/mise.local.toml\n/screenshots/\n")
    |> Deps.set_dep_option(:ithibati_starter, :only, :dev)
    |> Deps.set_dep_option(:ithibati_starter, :runtime, false)
  end

  defp gate(opts) do
    [
      "compile --warnings-as-errors",
      "deps.unlock --check-unused",
      "format --check-formatted",
      "credo --strict",
      "xref graph --label compile-connected --fail-above 0",
      "sobelow --exit"
    ] ++
      if(opts[:without_ithibati],
        do: [],
        else: ["ecto.create --quiet", "ecto.migrate --quiet", "ithibati.doctor"]
      ) ++
      ["assets.build", "test"]
  end

  defp database_env(igniter) do
    Enum.reduce(["config/dev.exs", "config/test.exs"], igniter, fn path, acc ->
      acc
      |> Files.replace(
        path,
        "username: \"postgres\"",
        "username: System.get_env(\"PGUSER\", \"postgres\")"
      )
      |> Files.replace(
        path,
        "password: \"postgres\"",
        "password: System.get_env(\"PGPASSWORD\", \"postgres\")"
      )
      |> Files.replace(
        path,
        "hostname: \"localhost\",",
        "hostname: System.get_env(\"PGHOST\", \"localhost\"),\n  port: String.to_integer(System.get_env(\"PGPORT\", \"5432\")),"
      )
    end)
  end

  defp tidy_scaffold(igniter, b) do
    igniter
    |> Files.replace(
      "lib/#{b.app}_web/components/core_components.ex",
      "alias Phoenix.LiveView.JS",
      "alias Phoenix.HTML.Form\n  alias Phoenix.LiveView.JS"
    )
    |> Files.replace(
      "lib/#{b.app}_web/components/core_components.ex",
      "Phoenix.HTML.Form.normalize_value",
      "Form.normalize_value"
    )
    |> Files.replace(
      "lib/#{b.app}_web.ex",
      "alias Phoenix.LiveView.JS\n      alias #{b.module}Web.Layouts",
      Enum.join(
        Enum.sort(["alias #{b.module}Web.Layouts", "alias Phoenix.LiveView.JS"]),
        "\n      "
      )
    )
    |> Files.replace(
      "test/support/data_case.ex",
      "use ExUnit.CaseTemplate",
      "use ExUnit.CaseTemplate\n  alias Ecto.Adapters.SQL.Sandbox"
    )
    |> Files.replace(
      "test/support/data_case.ex",
      "Ecto.Adapters.SQL.Sandbox.start_owner!",
      "Sandbox.start_owner!"
    )
    |> Files.replace(
      "test/support/data_case.ex",
      "Ecto.Adapters.SQL.Sandbox.stop_owner",
      "Sandbox.stop_owner"
    )
  end

  defp maybe_beans(igniter, bindings, opts) do
    if opts[:without_beans] do
      igniter
    else
      igniter
      |> Files.append(
        "mise.toml",
        "\n[tasks.beans]\nrun = \"beans list --no-status completed --no-status scrapped\"\n"
      )
      |> Files.append(
        ".gitignore",
        "\n# Local work tracking is intentionally not published.\n/.beans/\n/.beans.yml\n"
      )
      |> Igniter.create_new_file(
        ".beans.yml",
        "beans:\n  path: .beans\n  prefix: #{bindings.app}-\n  id_length: 4\n  default_status: todo\n  default_type: task\n"
      )
      |> Igniter.mkdir(".beans")
      |> Files.append(
        "CONTRIBUTING.md",
        "\n## Local Beans tracking\n\nInstall Beans separately. Search unfinished tickets before creating work; update\nprogress and finish with a Summary of Changes. Run `beans check` after changes.\n`.beans/` and `.beans.yml` are ignored and not backed up by Git pushes.\n"
      )
    end
  end
end
