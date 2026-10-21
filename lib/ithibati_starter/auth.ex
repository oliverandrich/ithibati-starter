defmodule IthibatiStarter.Auth do
  @moduledoc false
  alias Igniter.Project.Config
  alias Igniter.Project.Deps
  alias IthibatiStarter.Files

  def install(igniter, b) do
    app = String.to_atom(b.app)
    endpoint = Module.concat([b.module <> "Web", Endpoint])
    mailer = Module.concat([b.module, Mailer])
    repo = Module.concat([b.module, Repo])
    user = Module.concat([b.module, Accounts, User])
    invitation = Module.concat([b.module, Accounts, Invitation])

    igniter
    # A patch of the library is taken, a minor is not. The lockfile still decides what is
    # installed; this decides what an update may reach for.
    |> Deps.add_dep({:ithibati, "~> #{Files.ithibati_version()}"}, yes?: true)
    |> Deps.add_dep({:phoenix_test_playwright, "~> 0.19.0", only: :test, runtime: false},
      yes?: true
    )
    |> Deps.add_dep({:swoosh, "~> 1.28"}, yes?: true)
    |> Deps.add_dep({:gen_smtp, "~> 1.3"}, yes?: true)
    |> Files.copy_tree("auth", b)
    |> Files.replace("lib/#{b.app}/application.ex", "    children = [", """
        # Before anything binds a port. An instance whose claim is not protected must not
        # serve one request: the first stranger to arrive would be the one who claims it.
        #{b.module}.Claim.verify!()
        #{b.module}.Identity.verify!()

        children = [
          #{b.module}.AuthRateLimiter,\
    """)
    |> Files.replace(
      "lib/#{b.app}/application.ex",
      "skip: !Application.get_env(:#{b.app}, :migrate_on_start, false)},\n",
      """
      skip: !Application.get_env(:#{b.app}, :migrate_on_start, false)},
            {#{b.module}.IdentityCheck, skip: !Application.get_env(:#{b.app}, :migrate_on_start, false)},
      """
    )
    |> Config.configure("config.exs", :phoenix, [:filter_parameters], [
      "password",
      "secret",
      "token",
      "code",
      "setup_code",
      "credential"
    ])
    |> Config.configure("config.exs", :swoosh, [:api_client], false)
    |> Config.configure("dev.exs", app, [mailer, :adapter], Swoosh.Adapters.Local)
    |> Config.configure("dev.exs", app, [:mail_enabled], true)
    |> Config.configure("dev.exs", app, [:mail_from], {b.module, "invitations@localhost"})
    |> Config.configure("test.exs", app, [mailer, :adapter], Swoosh.Adapters.Test)
    |> Config.configure("test.exs", app, [:mail_from], {b.module, "invitations@example.test"})
    |> Config.configure("test.exs", :swoosh, [:local], false)
    |> Config.configure("prod.exs", :swoosh, [:local], false)
    |> Config.configure("prod.exs", :swoosh, [:api_client], false)
    |> Config.configure("config.exs", :ithibati, [:repo], repo)
    |> Config.configure("config.exs", :ithibati, [:user_schema], user)
    |> Config.configure("config.exs", :ithibati, [:invitation_schema], invitation)
    |> Config.configure("config.exs", :ithibati, [:users_key_type], :id)
    |> Config.configure("config.exs", :ithibati, [:initial_claim], :operator_code)
    |> Config.configure("test.exs", app, [endpoint, :server], true)
    |> Config.configure("test.exs", app, [:sql_sandbox], true)
    # LiveViewTest's client stands in for the WebSocket process and has no clause for
    # `:garbage_collect`. The hook's own test covers what it sends.
    |> Config.configure("test.exs", app, [:collect_transport_garbage], false)
    # Browser features all arrive from loopback and otherwise share the production setup budget.
    |> Config.configure("test.exs", app, [:auth_rate_limits], setup: {1_000, 60})
    |> Config.configure("test.exs", :phoenix_test, [:otp_app], app)
    |> Config.configure("test.exs", :phoenix_test, [:endpoint], endpoint)
    # The features were written against a three-second wait.
    |> Config.configure("test.exs", :phoenix_test, [:playwright, :timeout], 3_000)
    # A cold CI runner took longer than the default four seconds to start the browser.
    # Written as code, so the generated file keeps the underscore Credo asks for.
    |> Config.configure(
      "test.exs",
      :phoenix_test,
      [:playwright, :browser_launch_timeout],
      {:code, Sourceror.parse_string!("30_000")}
    )
    |> Config.configure(
      "test.exs",
      :phoenix_test,
      [:playwright, :screenshot],
      {:code, Sourceror.parse_string!(~s|System.get_env("PW_SCREENSHOT", "false") in ~w(t true)|)}
    )
    |> Igniter.create_new_file(
      "lib/#{b.app}_web/router.ex",
      Files.template("fragments/router", b),
      on_exists: :overwrite
    )
    |> Files.replace(
      "lib/#{b.app}_web/endpoint.ex",
      "same_site: \"Lax\"",
      "same_site: \"Lax\",\n    encryption_salt: #{inspect(Base.encode64(:crypto.strong_rand_bytes(12)))}"
    )
    |> Files.replace("lib/#{b.app}_web/endpoint.ex", "  plug Plug.RequestId", """
      # Before the request id and the telemetry, so a log line names the visitor rather than
      # the proxy that carried them.
      plug #{b.module}Web.ClientIp

      plug Plug.RequestId\
    """)
    |> Files.replace(
      "lib/#{b.app}_web/endpoint.ex",
      "  use Phoenix.Endpoint, otp_app: :#{b.app}\n",
      "  use Phoenix.Endpoint, otp_app: :#{b.app}\n\n  alias Ithibati.Identity.Sessions\n"
    )
    |> Files.replace(
      "lib/#{b.app}_web/endpoint.ex",
      "  plug Plug.Session, @session_options\n  plug #{b.module}Web.Router\nend",
      """
        plug :session
        plug #{b.module}Web.Router

        # Without a max age the browser drops the cookie when it closes. The validity is read per
        # request, so `config/runtime.exs` may set it.
        defp session(conn, _opts) do
          options = Keyword.put(@session_options, :max_age, Sessions.max_age())
          Plug.Session.call(conn, Plug.Session.init(options))
        end
      end\
      """
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
      "import \"./recovery_codes\"\nimport {InvitationLink} from \"./invitation_link\"\nimport {CopyText} from \"./copy_text\"\nimport {ShrinkTitle} from \"./shrink_title\"\nimport {hooks as ithibatiHooks} from \"ithibati\"\nimport {Socket}"
    )
    |> Files.replace(
      "assets/js/app.js",
      "hooks: {...colocatedHooks}",
      "hooks: {...colocatedHooks, ...ithibatiHooks, InvitationLink, CopyText, ShrinkTitle}"
    )
    |> Files.replace(
      "config/runtime.exs",
      "System.get_env(\"PORT\", \"4000\")",
      "System.get_env(\"PORT\", if(config_env() == :test, do: \"4102\", else: \"4000\"))"
    )
    |> Files.append("config/runtime.exs", Files.template("fragments/trusted_proxies_runtime", b))
    |> Files.append("config/runtime.exs", Files.template("fragments/mail_runtime", b))
    |> Files.append("config/runtime.exs", Files.template("fragments/account_identity_runtime", b))
    |> Files.replace(
      "test/#{b.app}_web/controllers/page_controller_test.exs",
      "assert html_response(conn, 200) =~ \"Peace of mind from prototype to production\"",
      "assert redirected_to(conn) == ~p\"/login\""
    )
    |> Files.replace(
      "test/support/data_case.ex",
      "  def setup_sandbox(tags) do\n",
      "  def setup_sandbox(tags) do\n    #{b.module}.SetupSupport.forget_rate_limits()\n"
    )
    |> Files.append("test/test_helper.exs", """

    # The PostgreSQL pass excludes the browser features, so it needs neither node nor Playwright.
    ex_unit = ExUnit.configuration()

    if :feature in ex_unit[:include] or :feature not in ex_unit[:exclude] do
      Application.put_env(:phoenix_test, :base_url, #{b.module}Web.Endpoint.url())
      {:ok, _} = PhoenixTest.Playwright.Supervisor.start_link()
    end
    """)
  end
end
