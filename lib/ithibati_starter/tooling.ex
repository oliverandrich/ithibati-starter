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
    {:mix_audit, "~> 2.1.5", only: [:dev, :test], runtime: false}
  ]

  def install(igniter, bindings, opts) do
    igniter = Enum.reduce(@deps, igniter, &Deps.add_dep(&2, &1, yes?: true))

    igniter
    |> IgniterConfig.dont_move_file_pattern(~r/^(lib|test)\//)
    |> Deps.remove_dep(:daisyui)
    |> Deps.remove_dep(:heroicons)
    |> Igniter.add_task("deps.unlock", ["daisyui", "heroicons"])
    |> Igniter.rm("assets/vendor/heroicons.js")
    |> Files.copy_tree("tooling", bindings, on_exists: :overwrite)
    |> Igniter.add_task("cmd", [
      "chmod +x rel/overlays/bin/server rel/overlays/bin/migrate rel/overlays/bin/setup-code"
    ])
    |> MixProject.update(:project, [:elixir], fn _ -> {:ok, {:code, inspect("~> 1.20")}} end)
    |> MixProject.update(:cli, [:preferred_envs, :precommit], fn _ -> {:ok, {:code, :test}} end)
    |> MixProject.update(:project, [:aliases, :precommit], fn _ -> {:ok, {:code, gate()}} end)
    |> Config.configure("config.exs", :tailwind, [:version], "4.3.3")
    |> Config.configure("config.exs", String.to_atom(bindings.app), [:locales], ["en", "de"])
    |> Config.configure(
      "config.exs",
      String.to_atom(bindings.app),
      [Module.concat([bindings.module <> "Web", Gettext]), :default_locale],
      "en"
    )
    |> databases(bindings)
    |> Files.replace("lib/#{bindings.app}/application.ex", "      #{bindings.module}.Repo,\n", """
          #{bindings.module}.Repo,
          # A release migrates here, before the endpoint serves anything; see config/runtime.exs.
          # Development and tests migrate by hand.
          {Ecto.Migrator,
           repos: Application.fetch_env!(:#{bindings.app}, :ecto_repos),
           skip: !Application.get_env(:#{bindings.app}, :migrate_on_start, false)},
    """)
    |> Files.append(
      "config/runtime.exs",
      Files.template("fragments/migrate_on_start_runtime", bindings)
    )
    |> logging(bindings)
    |> tidy_scaffold(bindings)
    |> maybe_beans(bindings, opts)
    |> Files.append(".gitignore", "\n/mise.local.toml\n/screenshots/\n")
    |> Deps.set_dep_option(:ithibati_starter, :only, :dev)
    |> Deps.set_dep_option(:ithibati_starter, :runtime, false)
  end

  defp gate do
    [
      "compile --warnings-as-errors",
      "deps.unlock --check-unused",
      "format --check-formatted",
      "credo --strict",
      "xref graph --label compile-connected --fail-above 0",
      "sobelow --exit",
      "ecto.create --quiet",
      "ecto.migrate --quiet",
      "ithibati.doctor",
      "assets.build",
      "test"
    ]
  end

  # Phoenix scaffolds PostgreSQL. The repository becomes a dispatcher over one repository per
  # database, and each environment configures the one `<APP>_DATABASE` names.
  defp databases(igniter, b) do
    repo = "config :#{b.app}, #{b.module}.Repo,\n"

    igniter
    |> Deps.add_dep({:ecto_sqlite3, "~> 0.25"}, yes?: true)
    |> Files.replace(
      "config/config.exs",
      "# Import environment specific config.",
      Files.template("fragments/database_config", b) <> "\n# Import environment specific config."
    )
    |> Files.replace(
      "config/dev.exs",
      repo <>
        scaffold_credentials() <>
        """
          database: "#{b.app}_dev",
          stacktrace: true,
          show_sensitive_data_on_connection_error: true,
          pool_size: 10
        """,
      Files.template("fragments/database_dev", b)
    )
    |> Files.replace(
      "config/test.exs",
      repo <>
        scaffold_credentials() <>
        """
          database: "#{b.app}_test\#{System.get_env("MIX_TEST_PARTITION")}",
          pool: Ecto.Adapters.SQL.Sandbox,
          pool_size: System.schedulers_online() * 2
        """,
      Files.template("fragments/database_test", b)
    )
    # The scaffold's PostgreSQL block becomes the else branch; `mix format` indents it.
    |> Files.replace("config/runtime.exs", [
      {"  database_url =\n",
       Files.template("fragments/database_runtime", b) <> "  database_url =\n"},
      {"    socket_options: maybe_ipv6\n", "    socket_options: maybe_ipv6\n  end\n"}
    ])
    |> Files.replace(
      "test/test_helper.exs",
      "ExUnit.start()\n",
      Files.template("fragments/database_test_helper", b)
    )
  end

  defp scaffold_credentials do
    """
      username: "postgres",
      password: "postgres",
      hostname: "localhost",
    """
  end

  defp logging(igniter, b) do
    igniter
    |> Deps.add_dep({:logger_json, "~> 7.0"}, yes?: true)
    |> Files.replace("config/prod.exs", "config :logger, level: :info\n", """
    config :logger, level: :info

    # No access log. See docs/operations.md.
    config :phoenix, :logger, false
    """)
    |> Files.append("config/runtime.exs", Files.template("fragments/logging_runtime", b))
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
