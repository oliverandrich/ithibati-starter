defmodule IthibatiStarter.Auth do
  @moduledoc false
  alias Igniter.Project.Config
  alias Igniter.Project.Deps
  alias IthibatiStarter.Files

  def install(igniter, b) do
    app = String.to_atom(b.app)
    endpoint = Module.concat([b.module <> "Web", Endpoint])
    repo = Module.concat([b.module, Repo])
    user = Module.concat([b.module, Accounts, User])
    invitation = Module.concat([b.module, Accounts, Invitation])

    igniter
    |> Deps.add_dep({:ithibati, "== 0.4.0"}, yes?: true)
    |> Deps.add_dep({:wallaby, "~> 0.31.0", only: :test, runtime: false}, yes?: true)
    |> Files.copy_tree("auth", b)
    |> Files.replace(
      "lib/#{b.app}/application.ex",
      "children = [",
      "children = [\n      #{b.module}.AuthRateLimiter,"
    )
    |> Config.configure("config.exs", :phoenix, [:filter_parameters], [
      "password",
      "secret",
      "token",
      "code",
      "credential"
    ])
    |> Config.configure("config.exs", :ithibati, [:repo], repo)
    |> Config.configure("config.exs", :ithibati, [:user_schema], user)
    |> Config.configure("config.exs", :ithibati, [:invitation_schema], invitation)
    |> Config.configure("config.exs", :ithibati, [:users_key_type], :id)
    |> Config.configure("test.exs", app, [endpoint, :server], true)
    |> Config.configure("test.exs", app, [:sql_sandbox], true)
    |> Config.configure("test.exs", :wallaby, [:otp_app], app)
    |> Config.configure("test.exs", :wallaby, [:driver], Wallaby.Chrome)
    |> Config.configure("test.exs", :wallaby, [:js_logger], nil)
    |> Config.configure("test.exs", :wallaby, [:screenshot_on_failure], true)
    |> Igniter.create_new_file(
      "lib/#{b.app}_web/router.ex",
      Files.template("fragments/router", b),
      on_exists: :overwrite
    )
    |> Files.replace(
      "lib/#{b.app}_web/components/layouts.ex",
      "embed_templates \"layouts/*\"",
      "embed_templates \"layouts/*\"\n" <> Files.template("fragments/layout_helpers", b)
    )
    |> Files.replace(
      "lib/#{b.app}_web/endpoint.ex",
      "same_site: \"Lax\"",
      "same_site: \"Lax\",\n    encryption_salt: #{inspect(Base.encode64(:crypto.strong_rand_bytes(12)))}"
    )
    |> Files.replace("lib/#{b.app}_web/endpoint.ex", "  plug Plug.Static,", """
      if Application.compile_env(:#{b.app}, :sql_sandbox, false) do
        plug Phoenix.Ecto.SQL.Sandbox
      end

      plug Plug.Static,
    """)
    |> Files.replace(
      "assets/js/app.js",
      "import {Socket}",
      "import \"./recovery_codes\"\nimport {hooks as ithibatiHooks} from \"ithibati\"\nimport {Socket}"
    )
    |> Files.replace(
      "assets/js/app.js",
      "hooks: {...colocatedHooks}",
      "hooks: {...colocatedHooks, ...ithibatiHooks}"
    )
    |> Files.replace(
      "config/runtime.exs",
      "System.get_env(\"PORT\", \"4000\")",
      "System.get_env(\"PORT\", if(config_env() == :test, do: \"4102\", else: \"4000\"))"
    )
    |> Files.replace(
      "test/#{b.app}_web/controllers/page_controller_test.exs",
      "assert html_response(conn, 200) =~ \"Peace of mind from prototype to production\"",
      "assert redirected_to(conn) == ~p\"/login\""
    )
    |> Files.append("test/test_helper.exs", """

    Application.put_env(:wallaby, :chromedriver, path: #{b.module}Web.BrowserDriver.path(), headless: true)
    Application.put_env(:wallaby, :base_url, #{b.module}Web.Endpoint.url())
    {:ok, _} = Application.ensure_all_started(:wallaby)
    """)
  end
end
