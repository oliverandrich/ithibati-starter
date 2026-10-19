defmodule IthibatiStarterTest do
  use ExUnit.Case, async: true
  import Igniter.Test
  alias Mix.Tasks.IthibatiStarter.Install

  # The scaffold `phx.new` writes with a mailer, which is the only one the installer accepts:
  # the second directory holds the files that differ from the plain one and wins where both have
  # the same path.
  @fixtures ["test/fixtures/phoenix", "test/fixtures/phoenix_mailer"]

  defp project(extra \\ %{}) do
    files =
      Enum.reduce(@fixtures, %{}, fn root, acc ->
        root
        |> Path.join("**/*.txt")
        |> Path.wildcard(match_dot: true)
        |> Enum.into(acc, fn path ->
          {path |> Path.relative_to(root) |> String.trim_trailing(".txt"), File.read!(path)}
        end)
      end)

    files =
      Map.put(
        files,
        ".formatter.exs",
        "[locals_without_parens: [embed_templates: 1, plug: 1, plug: 2], inputs: [\"**/*.{ex,exs}\"]]"
      )

    test_project(app_name: :sample, files: Map.merge(files, extra))
  end

  for opts <- [[], [without_beans: true]] do
    @documentation_opts opts
    @tag :documentation
    test "documentation separates contribution workflow from application guides for #{inspect(opts)}" do
      result = project() |> install(@documentation_opts) |> apply_igniter!()
      files = result.assigns.test_files

      assert files["docs/operations.md"] =~ "bin/migrate"
      assert files["docs/operations.md"] =~ "bin/setup-code"
      assert files["docs/operations.md"] =~ "Sample.AuthCleanup.run()"
      assert files["docs/authentication.md"] =~ "invite: {20, 86_400}"
      assert files["docs/authentication.md"] =~ "initial_claim: :operator_code"
      assert files["docs/operations.md"] =~ "TRUSTED_PROXIES"
      assert files["docs/authentication.md"] =~ "[Operations](operations.md)"
      assert files["docs/authentication.md"] =~ "pins Ithibati 0.9.0"
      assert files["docs/localization.md"] =~ "Accept-Language"
      assert files["docs/interface.md"] =~ "Layouts.member/1"
      assert files["docs/interface.md"] =~ "SampleWeb.Navigation"
      assert files["docs/interface.md"] =~ "group_link/1"
      assert files["README.md"] =~ "[Interface](docs/interface.md)"
      assert files["CONTRIBUTING.md"] =~ "[Interface](docs/interface.md)"
      assert files["CONTRIBUTING.md"] =~ "Chrome"
      refute files["CONTRIBUTING.md"] =~ "## Authentication limits"
      refute files["CONTRIBUTING.md"] =~ "## Health, releases"
      assert files["README.md"] =~ "docs/operations.md"
      assert files["README.md"] =~ "Ithibati Starter 0.9.0"
      assert files["README.md"] =~ "mise run setup-code"
      assert files["AGENTS.md"] =~ "Documentation structure"
      refute Map.has_key?(files, "docs/development.md")

      # Delivery is part of the application now, not a profile with a guide of its own.
      refute Map.has_key?(files, "docs/mail.md")
      assert files["docs/operations.md"] =~ "SMTP_HOST"
      assert files["docs/operations.md"] =~ "ACCOUNT_IDENTITY"
      assert files["docs/authentication.md"] =~ "named or addressed"
      refute files["CONTRIBUTING.md"] =~ "SMTP_HOST"

      for {path, content} <- files,
          String.ends_with?(path, ".md"),
          [_, link] <- Regex.scan(~r/\[[^\]]+\]\(([^)]+)\)/, content),
          URI.parse(link).scheme == nil,
          not String.starts_with?(link, "#") do
        target =
          link
          |> String.split("#")
          |> hd()
          |> Path.expand(Path.dirname("/" <> path))
          |> Path.relative_to("/")

        assert Map.has_key?(files, target), "#{path} links to missing #{target}"
      end

      result |> install(@documentation_opts) |> assert_unchanged()
    end
  end

  test "default profile installs pinned invitation authentication and tooling" do
    result = project() |> install()
    assert Mix.Project.config()[:version] == "0.9.0"

    assert_creates(result, ".ithibati-starter", fn text ->
      assert String.starts_with?(text, "0.9.0\n")
    end)

    assert_has_task(result, "format", [])
    assert_creates(result, "lib/sample/accounts/invitation.ex")
    assert_creates(result, "lib/sample_web/live/sign_in_live.ex")
    assert_creates(result, "mise.toml", fn text -> assert text =~ "mix precommit" end)

    assert_creates(result, ".github/workflows/ci.yml", fn text ->
      assert text =~ "mise run check"
    end)

    # A patch of the library is taken, a minor is not. The lockfile still decides what is
    # installed; this decides what an update may reach for.
    assert diff(result, only: "mix.exs") =~ ~s({:ithibati, "~> 0.9.0"})
    assert diff(result, only: "mix.exs") =~ "ithibati.doctor"
    assert diff(result, only: "lib/sample_web/router.ex") =~ "ithibati_routes"
    assert diff(result, only: "config/config.exs") =~ ~s("setup_code")

    refute diff(result, only: "mix.exs") =~ ":tidewave"
    refute diff(result, only: "lib/sample_web/endpoint.ex") =~ "plug Tidewave"
  end

  # A token in the path reaches access logs, browser history and the LiveView's join URL. The
  # fragment reaches none of them.
  test "an invitation link carries its token in the fragment" do
    files = installed_files()

    assert files["lib/sample_web/router.ex"] =~ ~s{live("/invite", InviteLive)}
    refute files["lib/sample_web/router.ex"] =~ "/invite/:token"
    assert files["lib/sample_web/live/invitations_live.ex"] =~ ~S{url(~p"/invite") <> "#" <>}
    assert files["assets/js/app.js"] =~ ~s(import {InvitationLink} from "./invitation_link")

    assert files["assets/js/app.js"] =~
             "hooks: {...colocatedHooks, ...ithibatiHooks, InvitationLink, CopyText, ShrinkTitle}"

    assert files["assets/js/invitation_link.js"] =~ "history.replaceState"

    # The link and the recovery codes copy through one module.
    assert files["assets/js/app.js"] =~ ~s(import {CopyText} from "./copy_text")
    assert files["assets/js/copy_text.js"] =~ "export async function copyText"
    assert files["assets/js/recovery_codes.js"] =~ ~s(import {copyText} from "./copy_text")
  end

  test "the member shell ships its navigation, title hook and safe-area variables" do
    files = installed_files()

    assert files["lib/sample_web/navigation.ex"] =~ "def items(_account)"
    assert files["lib/sample_web/navigation.ex"] =~ ~s(section: :home)
    assert files["lib/sample_web/components/layouts.ex"] =~ "SampleWeb.Navigation.items("
    assert files["assets/js/app.js"] =~ ~s(import {ShrinkTitle} from "./shrink_title")
    assert files["assets/js/app.js"] =~ ~r/hooks: \{[^}]*\bShrinkTitle\b/
    assert files["assets/js/shrink_title.js"] =~ "export const ShrinkTitle"
    assert files["assets/css/app.css"] =~ "--nav-bar: 49px;"
    assert files["assets/css/app.css"] =~ "--safe-bottom: env(safe-area-inset-bottom, 0px);"
    assert files["lib/sample_web/components/core_components.ex"] =~ "<h1 data-large-title"
    assert files["lib/sample_web/live/inside_live.ex"] =~ "section={:home}"
    assert files["test/sample_web/components/member_layout_test.exs"] =~ "layout={:columns}"
    assert files["test/features/shell_test.exs"] =~ "data-shrunk"
  end

  # Starting Chrome is most of a short feature's runtime, so the features share one session.
  test "the browser features share one Chrome session" do
    files = installed_files()

    assert files["test/test_helper.exs"] =~ "{:ok, _} = SampleWeb.BrowserPool.start()"

    assert files["test/test_helper.exs"] =~
             "ExUnit.after_suite(fn _ -> SampleWeb.BrowserPool.stop() end)"

    assert files["test/support/feature_case.ex"] =~ "BrowserPool.checkout()"
    refute files["test/support/feature_case.ex"] =~ "use Wallaby.Feature"
    assert files["test/support/browser_pool.ex"] =~ "Storage.clearDataForOrigin"
  end

  # A starter fix reaches an application only when somebody copies it. The drift test names the
  # generated files a starter update changed.
  test "an application compares its generated files with the starter's templates" do
    files = installed_files()

    assert files["test/sample/starter_drift_test.exs"] =~ "@owned []"
    assert files["test/support/starter_drift.ex"] =~ "Code.string_to_quoted!"

    # The placeholders are assembled from parts, so the installer leaves them alone.
    assert files["test/support/starter_drift.ex"] =~ ~s("__" <> "MODULE" <> "__")
  end

  test "generated protected claim and invitation table sit on the library's versions" do
    files = installed_files()

    assert files["config/config.exs"] =~ "initial_claim: :operator_code"

    assert files["priv/repo/migrations/20260920000000_add_setup_codes.exs"] =~
             "Ithibati.Migration.up(from: 2, version: 3)"

    # A table generated today is built at the version the library is on. `ithibati_invitation/0`
    # declares the inviter from 4, so a table pinned lower has a column every invitation query
    # asks for and the table does not answer.
    assert files["priv/repo/migrations/20260913115900_create_invitations.exs"] =~
             "Ithibati.Migration.invitation_columns(version: 4)"

    # Version 5 lets an invitation leave the name to the invitee. The table opens in a migration
    # of its own, so an application generated earlier gains the same file.
    opened = files["priv/repo/migrations/20261017000000_open_invitations.exs"]
    assert opened =~ "Ithibati.Migration.open_invitations(version: 5)"
    assert opened =~ "Ithibati.Migration.up(from: 3, version: 5)"

    refute Map.has_key?(
             files,
             "priv/repo/migrations/20260919000000_create_initial_setup_codes.exs"
           )

    assert files["lib/sample_web/auth.ex"] =~ "Instance.claim(authorization: authorization)"
    refute files["lib/sample_web/auth.ex"] =~ "InitialSetup.consume"
  end

  test "an unsupported claim mode stops the boot instead of offering a field nobody can satisfy" do
    files = installed_files()

    assert files["lib/sample/claim.ex"] =~ "Config.initial_claim_mode()"
    assert files["lib/sample/claim.ex"] =~ ":operator_code"
    assert Map.has_key?(files, "test/sample/claim_test.exs")

    assert [_, started] = String.split(files["lib/sample/application.ex"], "Claim.verify!()")
    assert started =~ "children = ["

    assert files["lib/sample/initial_setup.ex"] =~ "Claim.verify!()"
  end

  test "a request forwarded by a trusted proxy is counted against the visitor" do
    files = installed_files()

    client_ip = files["lib/sample_web/client_ip.ex"]
    assert client_ip =~ ":trusted_proxies"
    # A proxy writes one header and hands the rest through as the visitor wrote them.
    assert client_ip =~ ~s(@header "x-forwarded-for")

    # Every address-keyed budget counts the visitor this plug resolved, not the socket.
    assert files["lib/sample_web/auth_rate_limit.ex"] =~ "ClientIp.bucket(conn.remote_ip)"

    assert files["lib/sample_web/controllers/setup_controller.ex"] =~
             "AuthRateLimit.key(conn, :setup)"

    assert Map.has_key?(files, "test/sample_web/client_ip_test.exs")

    # Before the request id, so a log line names the visitor rather than the proxy.
    assert [_, logged] =
             String.split(files["lib/sample_web/endpoint.ex"], "plug SampleWeb.ClientIp")

    assert logged =~ "plug Plug.RequestId"

    assert files["config/runtime.exs"] =~ "TRUSTED_PROXIES"
    # Each entry is read by the plug that uses it, an address or a range.
    assert files["config/runtime.exs"] =~ "SampleWeb.ClientIp.parse_proxy(name)"
    assert Map.has_key?(files, "test/sample_web/trusted_proxies_test.exs")
  end

  test "the session cookie lasts as long as the session it carries" do
    endpoint =
      project()
      |> install()
      |> apply_igniter!()
      |> then(& &1.assigns.test_files["lib/sample_web/endpoint.ex"])

    refute endpoint =~ "plug Plug.Session, @session_options"
    assert endpoint =~ "plug :session"
    assert endpoint =~ "alias Ithibati.Identity.Sessions"
    assert endpoint =~ "Keyword.put(@session_options, :max_age, Sessions.max_age())"
    # The socket only reads the cookie, so it keeps the options without a max age.
    assert endpoint =~ "websocket: [connect_info: [session: @session_options]]"
  end

  # Phoenix already forces HTTPS in config/prod.exs, so the runtime advice to add it misleads.
  test "the runtime config no longer advises forcing HTTPS, and a test pins it" do
    files = installed_files()

    refute files["config/runtime.exs"] =~ "We also recommend setting `force_ssl`"
    assert files["test/sample_web/prod_config_test.exs"] =~ "force_ssl"
  end

  test "a release migrates before it serves, unless the operator opts out" do
    files = installed_files()

    assert [_, after_repo] = String.split(files["lib/sample/application.ex"], "Sample.Repo,")
    assert [_, after_migrator] = String.split(after_repo, "{Ecto.Migrator,")
    assert after_migrator =~ "skip: !Application.get_env(:sample, :migrate_on_start, false)"
    assert after_migrator =~ "SampleWeb.Endpoint"

    assert files["config/runtime.exs"] =~ "SAMPLE_MIGRATE_ON_START"
    assert files["test/sample/migrate_on_start_test.exs"] =~ "SAMPLE_MIGRATE_ON_START"
    assert files["docs/operations.md"] =~ "SAMPLE_MIGRATE_ON_START"
  end

  test "one build serves SQLite and PostgreSQL, and SAMPLE_DATABASE chooses" do
    files = installed_files()

    # Ecto fixes an adapter when a repository compiles, so each database has its own.
    assert files["lib/sample/repo.ex"] =~ "def repo do"
    assert files["lib/sample/repo/sqlite.ex"] =~ "adapter: Ecto.Adapters.SQLite3"
    assert files["lib/sample/repo/postgres.ex"] =~ "adapter: Ecto.Adapters.Postgres"
    assert files["config/config.exs"] =~ "ecto_repos: [Sample.Repo]"

    # `__MODULE__` is the template's placeholder for the application module, so the
    # repositories name themselves through `__ENV__` and read the shared `Sample.Repo` key.
    assert files["lib/sample/repo.ex"] =~ "Application.get_env(Sample.Repo, [])"
    assert files["lib/sample/repo.ex"] =~ "Keyword.put_new(:name, Sample.Repo)"

    for repo <- ["sqlite", "postgres"] do
      assert files["lib/sample/repo/#{repo}.ex"] =~ "@name __ENV__.module |> Module.split()"
    end

    assert files["mix.exs"] =~ ~s({:ecto_sqlite3,)
    # Before the environment files, so dev.exs or test.exs may override the choice.
    assert [before_import, _] = String.split(files["config/config.exs"], "import_config")
    assert before_import =~ ~s{System.get_env("SAMPLE_DATABASE", "sqlite")}

    for env <- ["dev", "test"] do
      assert files["config/#{env}.exs"] =~ ~s{"../tmp/sample_#{env}}
      assert files["config/#{env}.exs"] =~ ~s{System.get_env("PGHOST", "localhost")}
    end

    assert files["config/runtime.exs"] =~ ~s{System.get_env("SAMPLE_DATABASE", "sqlite")}
    assert files["config/runtime.exs"] =~ "DATABASE_PATH"
    assert files["config/runtime.exs"] =~ "DATABASE_URL"
    assert files["test/test_helper.exs"] =~ "max_cases: 1"

    assert files["mise.toml"] =~ "SAMPLE_DATABASE=sqlite mix precommit"
    assert files["mise.toml"] =~ "SAMPLE_DATABASE=postgres mix test"
    assert files["mise.toml"] =~ ~s(run = "SAMPLE_DATABASE=sqlite mix test")
    assert files[".github/workflows/ci.yml"] =~ "mise run check"
    assert files["docs/operations.md"] =~ "SAMPLE_DATABASE"
    assert files["docs/operations.md"] =~ "DATABASE_PATH"
    assert files["README.md"] =~ "SAMPLE_DATABASE=postgres"
  end

  test "a release logs JSON lines at LOG_LEVEL, without request paths" do
    files = installed_files()

    assert files["mix.exs"] =~ ~s({:logger_json,)
    assert files["lib/sample/logging.ex"] =~ "def drop_request("
    assert files["test/sample/logging_test.exs"] =~ "Sample.Logging"
    assert files["config/runtime.exs"] =~ ~s{Sample.Logging.level(System.get_env("LOG_LEVEL"))}
    assert files["config/runtime.exs"] =~ "formatter: Sample.Logging.formatter()"
    assert files["config/runtime.exs"] =~ "filters: Sample.Logging.filters()"
    assert files["config/prod.exs"] =~ "config :phoenix, :logger, false"
    assert files["docs/operations.md"] =~ "LOG_LEVEL"
  end

  test "a member page asks its WebSocket process to collect garbage after joining" do
    files = installed_files()

    assert files["lib/sample_web/transport_garbage.ex"] =~
             "send(socket.transport_pid, :garbage_collect)"

    assert files["test/sample_web/transport_garbage_test.exs"] =~ "SampleWeb.TransportGarbage"

    assert [_, members] = String.split(files["lib/sample_web/router.ex"], "live_session :members")
    assert members =~ "{SampleWeb.TransportGarbage, :collect}"
    assert files["config/test.exs"] =~ "collect_transport_garbage: false"
  end

  test "the check scans every commit for secrets" do
    files = installed_files()

    assert files["mise.toml"] =~ ~r/^gitleaks = "\d+\.\d+\.\d+"$/m
    assert files["mise.toml"] =~ "gitleaks git --redact --no-banner"
    assert files["mise.toml"] =~ "gitleaks git --staged --redact --no-banner"
    assert files["mise.toml"] =~ "gitleaks git --pre-commit --redact --no-banner"
    assert files[".github/workflows/ci.yml"] =~ "fetch-depth: 0"
    assert files[".gitleaks.toml"] =~ "useDefault = true"
    assert files["CONTRIBUTING.md"] =~ "gitleaks"
  end

  @tag :command_contract
  test "mise exposes development, reset and release commands" do
    result = project() |> install()

    assert_creates(result, "mise.toml", fn text ->
      assert text =~ "[tasks.setup-code]"

      assert text =~
               ~s|run = "env -u PHX_SERVER mix run -e 'Sample.InitialSetup.print_code!()'"|

      assert text =~ "[tasks.reset]"
      assert text =~ ~s(run = "mix ecto.reset")
      assert text =~ "[tasks.release]"
      assert text =~ ~s(env.MIX_ENV = "prod")
      assert text =~ "mix assets.deploy"
      assert text =~ "mix release --overwrite"
    end)
  end

  @tag :command_contract
  test "release launchers start the server, migrate and issue setup codes from any directory" do
    result = project() |> install() |> apply_igniter!()
    files = result.assigns.test_files

    directory =
      Path.join(System.tmp_dir!(), "starter release #{System.unique_integer([:positive])}")

    File.mkdir_p!(directory)
    on_exit(fn -> File.rm_rf!(directory) end)
    app = Path.join(directory, "sample")
    File.write!(app, "#!/bin/sh\nprintf '%s\\n' \"$PHX_SERVER\" \"$@\"\nexit 17\n")
    File.chmod!(app, 0o755)

    for {name, expected} <- [
          {"server", "true\nstart\n"},
          {"migrate", "\neval\nSample.Release.migrate()\n"},
          {"setup-code", "\neval\nSample.InitialSetup.print_code!()\n"}
        ] do
      source = Map.fetch!(files, "rel/overlays/bin/#{name}")
      path = Path.join(directory, name)
      File.write!(path, source)
      assert {^expected, 17} = System.cmd("sh", [path], cd: "/", env: [{"PHX_SERVER", nil}])

      if name == "setup-code" do
        assert {^expected, 17} =
                 System.cmd("sh", [path], cd: "/", env: [{"PHX_SERVER", "true"}])
      end
    end
  end

  test "there is one profile left; Beans, the brand colour and the license are the choices" do
    info = Install.info([], nil)
    refute Keyword.has_key?(info.schema, :with_mail)
    refute Keyword.has_key?(info.schema, :without_ithibati)
    assert info.schema[:without_beans] == :boolean
    assert info.schema[:brand] == :string
    assert info.schema[:license] == :string
    assert info.schema[:copyright] == :string
    assert info.schema[:source_url] == :string

    result = project() |> install(without_beans: true)
    assert_creates(result, "lib/sample/accounts/user.ex")
    refute_creates(result, ".beans.yml")
    refute diff(result, only: "mise.toml") =~ "beans list"
  end

  test "an account is named or addressed, and the instance decides at runtime" do
    result = project() |> install()
    assert_creates(result, "lib/sample/identity.ex")
    assert_creates(result, "lib/sample_web/invitation_mail.ex")
    assert_creates(result, "test/sample/identity_test.exs")

    assert diff(result, only: "config/runtime.exs") =~ "ACCOUNT_IDENTITY"
    assert diff(result, only: "config/runtime.exs") =~ "MAIL_ENABLED"
    # 465 is implicit TLS and 587 is STARTTLS; neither is hardcoded against the other's port.
    assert diff(result, only: "config/runtime.exs") =~ "smtp_port == 465"

    files = result |> apply_igniter!() |> then(& &1.assigns.test_files)

    # The library binds the identifier field when it compiles, so the shape is all that is left to
    # choose, and neither schema may fix it. Naming the module that answers is not fixing it: the
    # pair is escaped into the generated changeset and asked on every one, so an instance can
    # still decide. A literal pattern here would be the mistake, and so would a schema doing the
    # validating itself after the fact.
    for schema <- ["lib/sample/accounts/user.ex", "lib/sample/accounts/invitation.ex"] do
      assert files[schema] =~ "format: {Sample.Identity, :format}", schema
      assert files[schema] =~ "format_message: {Sample.Identity, :format_message}", schema
      refute files[schema] =~ "~r/", schema
      refute files[schema] =~ "Identity.validate()", schema
    end

    assert [_, started] = String.split(files["lib/sample/application.ex"], "Identity.verify!()")
    assert started =~ "children = ["
  end

  test "every application ships the mailer, and the Phoenix one is adopted rather than replaced" do
    original = project()
    result = install(original)
    assert diff(result, only: "mix.exs") =~ ":swoosh"
    assert diff(result, only: "lib/sample_web/router.ex") =~ "MailboxPreview"

    installed = apply_igniter!(result)
    files = installed.assigns.test_files

    # Phoenix already configures both adapters; what matters is that they survive.
    assert files["config/dev.exs"] =~ "Swoosh.Adapters.Local"
    assert files["config/test.exs"] =~ "Swoosh.Adapters.Test"
    assert files["config/dev.exs"] =~ "mail_enabled: true"

    # Phoenix wrote the module and the starter leaves it as it found it, below the license line.
    assert files["lib/sample/mailer.ex"] ==
             "# SPDX-License-Identifier: MIT\n\n" <>
               original.assigns.test_files["lib/sample/mailer.ex"]

    assert files["config/prod.exs"] =~ "api_client: false"
    refute files["config/prod.exs"] =~ "Swoosh.ApiClient.Req"

    assert length(Regex.scan(~r/Plug.Swoosh.MailboxPreview/, files["lib/sample_web/router.ex"])) ==
             1

    assert length(Regex.scan(~r/\{:swoosh,/, files["mix.exs"])) == 1
    installed |> install() |> assert_unchanged()
  end

  test "a customized router with a Phoenix mailbox is still refused" do
    project()
    |> IthibatiStarter.Files.replace(
      "lib/sample_web/router.ex",
      "PageController, :home",
      "PageController, :custom"
    )
    |> apply_igniter!()
    |> install()
    |> assert_has_issue(&String.contains?(&1, "router"))
    |> assert_unchanged()
  end

  test "reapplying the same profile preserves user edits and produces no changes" do
    installed = project() |> install() |> apply_igniter!()
    result = installed |> install()
    assert_unchanged(result)
  end

  test "an installed profile from another version is not converted in silence" do
    project()
    |> install()
    |> apply_igniter!()
    |> IthibatiStarter.Files.replace(".ithibati-starter", "0.9.0", "0.3.0")
    |> apply_igniter!()
    |> install()
    |> assert_has_issue(&String.contains?(&1, "profile"))
  end

  test "non-Phoenix projects are refused before making changes" do
    result = test_project() |> install()
    assert_has_issue(result, &String.contains?(&1, "Phoenix"))
    assert_unchanged(result)
  end

  test "existing tooling is refused instead of overwritten" do
    result =
      project()
      |> Igniter.create_new_file("mise.toml", "# My existing tooling\n")
      |> apply_igniter!()
      |> install()

    assert_has_issue(result, &String.contains?(&1, "existing tooling"))
    assert_unchanged(result)
  end

  test "binary-id projects are refused before generating incompatible auth migrations" do
    result =
      project()
      |> IthibatiStarter.Files.append(
        "config/config.exs",
        "\nconfig :sample, generators: [binary_id: true]\n"
      )
      |> apply_igniter!()
      |> install()

    assert_has_issue(result, &String.contains?(&1, "binary_id"))
    assert_unchanged(result)
  end

  test "applying the installer keeps HTML modules beside their embedded templates" do
    result = project() |> install() |> apply_igniter!()
    assert Map.has_key?(result.assigns.test_files, "lib/sample_web/controllers/session_html.ex")
    assert Map.has_key?(result.assigns.test_files, "test/features/invitation_test.exs")
  end

  test "template aliases remain ordered for application names before Ithibati" do
    source = "  alias Ithibati.Identity.Grant\n  alias __MODULE__.Repo\n"

    assert IthibatiStarter.Files.render(source, %{app: "acme", module: "Acme", brand: "violet"}) ==
             "  alias Acme.Repo\n  alias Ithibati.Identity.Grant\n"
  end

  test "custom routes are refused instead of replaced" do
    result =
      project()
      |> IthibatiStarter.Files.replace(
        "lib/sample_web/router.ex",
        "get \"/\", PageController, :home",
        "get \"/custom\", PageController, :home"
      )
      |> apply_igniter!()
      |> install()

    assert_has_issue(result, &String.contains?(&1, "router"))
    assert_unchanged(result)
  end

  test "checks explicitly select the test environment even when the shell selects dev" do
    result = project() |> install()

    assert_creates(result, "mise.toml", fn text ->
      assert text =~ "env.MIX_ENV = \"test\""
    end)
  end

  for opts <- [[], [without_beans: true]] do
    @profile_opts opts
    test "Lucide replaces Heroicons in profile #{inspect(opts)}" do
      planned = project() |> install(@profile_opts)
      assert_has_task(planned, "deps.unlock", ["daisyui", "heroicons"])
      installed = apply_igniter!(planned)
      files = installed.assigns.test_files
      assert files["mix.exs"] =~ "{:lucide_icons, \"~> 2.4.0\"}"
      refute files["mix.exs"] =~ ":heroicons"
      refute Map.has_key?(files, "assets/vendor/heroicons.js")
      refute files["assets/css/app.css"] =~ "heroicons"
      assert files["lib/sample_web/components/core_components.ex"] =~ "Lucideicons.info"
      assert files["lib/sample_web/components/layouts.ex"] =~ "Lucideicons.loader_circle"

      for {path, content} <- files, String.starts_with?(path, "lib/") do
        refute content =~ "hero-", "Heroicon remains in #{path}"
      end
    end

    test "vanilla Tailwind replaces DaisyUI in profile #{inspect(opts)}" do
      installed = project() |> install(@profile_opts) |> apply_igniter!()
      files = installed.assigns.test_files
      refute files["mix.exs"] =~ ":daisyui"
      refute files["assets/css/app.css"] =~ "daisyui"
      assert files["assets/css/app.css"] =~ "@import \"tailwindcss\""
      refute files["assets/css/app.css"] =~ "@custom-variant dark"
      refute files["lib/sample_web/components/layouts.ex"] =~ "theme_toggle"
      refute files["lib/sample_web/components/layouts/root.html.heex"] =~ "localStorage"

      for {path, source} <- files,
          String.starts_with?(path, "lib/") do
        refute source =~
                 ~r/\b(?:btn(?:-[a-z]+)?|alert-(?:info|error|success|warning)|(?:bg|text|border)-base-[a-z0-9]+|(?:input|select|textarea)-error|table-zebra|list-row|rounded-box)\b/,
               "DaisyUI class remains in #{path}"
      end

      assert files["lib/sample_web/components/core_components.ex"] =~ "focus-visible:"
      assert files["lib/sample_web/components/layouts/root.html.heex"] =~ "bg-ground"
      assert files["assets/css/app.css"] =~ "@media (prefers-color-scheme: dark)"
    end
  end

  test "the brand colour is named once, in the stylesheet's tokens" do
    files = installed_files()

    assert files["assets/css/app.css"] =~ "--color-signal: var(--color-violet-500);"
    assert files["assets/css/app.css"] =~ "--color-signal: var(--color-violet-400);"
    assert files[".ithibati-starter"] =~ "brand=violet\n"

    files = installed_files(brand: "amber")

    assert files["assets/css/app.css"] =~ "--color-signal: var(--color-amber-500);"
    refute files["assets/css/app.css"] =~ "violet"
  end

  test "templates name colours by role, never by hue" do
    files = installed_files()

    hue =
      ~r/\b(?:bg|text|border|ring|ring-offset|inset-ring|outline|accent|caret|divide|decoration|placeholder|fill|stroke|shadow|from|via|to)-(?:slate|gray|zinc|neutral|stone|red|orange|amber|yellow|lime|green|emerald|teal|cyan|sky|blue|indigo|violet|purple|fuchsia|pink|rose|white|black)\b/

    for {path, source} <- files, String.starts_with?(path, "lib/") do
      refute source =~ hue, "#{path} names a hue: #{inspect(Regex.run(hue, source))}"
    end
  end

  # A 500 shade underline is below 3:1 on white for yellow, lime and amber.
  test "a link's underline uses the shade meant for text" do
    files = installed_files()

    [_, text_link] = String.split(files["assets/css/app.css"], "@utility text-link")
    assert text_link =~ "text-decoration-color: var(--color-signal-strong);"
  end

  test "alerts and cards are components, not copied class lists" do
    files = installed_files()

    components = "lib/sample_web/components/core_components.ex"
    assert files[components] =~ "def alert(assigns)"
    assert files[components] =~ "def card(assigns)"

    for {path, source} <- files, String.starts_with?(path, "lib/"), path != components do
      refute source =~ ~r/(?<![\w:-])bg-danger-surface/, "#{path} copies the alert classes"
      refute source =~ "ring-1 ring-line", "#{path} copies the card classes"
    end
  end

  test "an unknown brand colour is refused before making changes" do
    project = project()

    for brand <- ["zinc", "notacolour", "violet-500"] do
      project
      |> install(brand: brand)
      |> assert_has_issue(&String.contains?(&1, "brand"))
      |> assert_unchanged()
    end
  end

  describe "license" do
    test "MIT is the default, with the year and the copyright holder" do
      files = installed_files()
      year = Date.utc_today().year

      assert files["LICENSE"] =~ "MIT License"
      assert files["LICENSE"] =~ "Copyright (c) #{year} Sample Author"
      assert files["README.md"] =~ "## License"
      assert files["README.md"] =~ "`MIT`"
      assert files["README.md"] =~ "Copyright (c) #{year} Sample Author"
      assert files[".ithibati-starter"] =~ "license=mit\n"
      refute files["config/config.exs"] =~ "source_url"
    end

    test "AGPL ships the license text and its source code link" do
      files = installed_files(license: "agpl", source_url: "https://example.com/sample")

      assert files["LICENSE"] == File.read!("priv/templates/licenses/agpl.tpl")
      assert files["LICENSE"] =~ "GNU AFFERO GENERAL PUBLIC LICENSE"
      assert files["README.md"] =~ "`AGPL-3.0-or-later`"
      assert files["README.md"] =~ "Copyright (c) #{Date.utc_today().year} Sample Author"
      assert files[".ithibati-starter"] =~ "license=agpl\n"
      assert files["config/config.exs"] =~ ~s(source_url: "https://example.com/sample")
      assert files["config/runtime.exs"] =~ "SOURCE_URL"
      assert files["docs/operations.md"] =~ "`SOURCE_URL`"
    end

    # The component exists for both licenses, so the Elixir templates do not differ between them.
    test "every layout can render the source code link" do
      files = installed_files()
      layouts = files["lib/sample_web/components/layouts.ex"]

      assert layouts =~ "def source_offer(assigns)"
      assert layouts =~ "Application.get_env(:sample, :source_url)"
      assert Regex.scan(~r/<\.source_offer/, layouts) |> length() == 3
      # Without an address no wrapper renders, so an MIT application keeps its spacing.
      assert Regex.scan(~r/<\w+ :if=\{source_url\(\)\}/, layouts) |> length() == 3
    end

    test "an unknown license, a missing holder or a bad source URL is refused before changes" do
      project = project()

      for {opts, word} <- [
            {[license: "gpl"], "license"},
            {[license: "agpl"], "--source-url"},
            {[license: "agpl", source_url: "example.com/sample"], "--source-url"},
            {[license: "agpl", source_url: "ftp://example.com/sample"], "--source-url"},
            {[source_url: "https://example.com/sample"], "--source-url"},
            {[copyright: nil], "--copyright"},
            {[copyright: "  "], "--copyright"}
          ] do
        project
        |> install(opts)
        |> assert_has_issue(&String.contains?(&1, word))
        |> assert_unchanged()
      end
    end

    test "reapplying needs no holder, and another license is not converted" do
      installed = project() |> install() |> apply_igniter!()

      installed |> IthibatiStarter.install([]) |> assert_unchanged()

      installed
      |> install(license: "agpl", source_url: "https://example.com/sample")
      |> assert_has_issue(&String.contains?(&1, "profile"))
    end

    test "every source file states its license in its own comment syntax" do
      files = installed_files()
      marker = "SPDX-License-Identifier: MIT"

      assert files["lib/sample_web/router.ex"] =~ ~r/\A# #{marker}\n/
      assert files["mix.exs"] =~ ~r/\A# #{marker}\n/
      assert files["assets/js/app.js"] =~ ~r/\A\/\/ #{marker}\n/
      assert files["assets/css/app.css"] =~ ~r/\A\/\* #{marker} \*\/\n/

      assert files["lib/sample_web/controllers/page_html/home.html.heex"] =~
               ~r/\A<%!-- #{marker} --%>\n/

      # A doctype and a shebang must stay first.
      assert files["lib/sample_web/components/layouts/root.html.heex"] =~
               ~r/\A<!DOCTYPE html>\n<%!-- #{marker} --%>\n/

      assert files["rel/overlays/bin/server"] =~ ~r/\A#!\/bin\/sh\n# #{marker}\n/

      for {path, source} <- files, licensed?(path) do
        assert source |> String.split("\n") |> Enum.take(5) |> Enum.join("\n") =~ marker,
               "#{path} does not state its license"
      end

      assert files["test/sample/license_marker_test.exs"] =~ ~r/\A# #{marker}\n/

      # The generated check covers exactly what the installer marks.
      check = files["test/sample/license_marker_test.exs"]
      assert check =~ "@paths ~w(#{Enum.join(IthibatiStarter.License.paths(), " ")})"
      assert check =~ "@extensions ~w(#{Enum.join(IthibatiStarter.License.extensions(), " ")})"
    end

    test "third-party code keeps its own terms, even under a checked directory" do
      files =
        %{"assets/js/vendor/chart.js" => "export default {}\n"}
        |> project()
        |> install()
        |> apply_igniter!()
        |> then(& &1.assigns.test_files)

      assert files["assets/js/vendor/chart.js"] == "export default {}\n"
      refute files["assets/vendor/topbar.js"] =~ "SPDX"
    end

    # A file type without a known comment syntax is left alone rather than broken.
    test "only files with a known comment syntax are marked" do
      untouched = %{
        "test/support/fixtures/data.json" => ~s({"a": 1}\n),
        "lib/sample_web/.DS_Store" => <<0, 0, 0, 1, 66, 117, 100, 49>>,
        "assets/js/chart.ts" => "export const a = 1\n",
        "rel/overlays/bin/README" => "Start commands.\n"
      }

      marked = %{
        "assets/js/lazy.mjs" => "export default 1\n",
        "rel/overlays/bin/backup" => "#!/bin/sh",
        "lib/sample_web/components/layouts/plain.html.heex" => "<!doctype html>"
      }

      files =
        untouched
        |> Map.merge(marked)
        |> project()
        |> install()
        |> apply_igniter!()
        |> then(& &1.assigns.test_files)

      for {path, content} <- untouched, do: assert(files[path] == content, path)

      assert files["assets/js/lazy.mjs"] =~ ~r/\A\/\/ SPDX-License-Identifier: MIT\n/

      # Without a trailing newline, and with a lowercase doctype, the first line still stays first.
      assert files["rel/overlays/bin/backup"] == "#!/bin/sh\n# SPDX-License-Identifier: MIT\n"

      assert files["lib/sample_web/components/layouts/plain.html.heex"] ==
               "<!doctype html>\n<%!-- SPDX-License-Identifier: MIT --%>\n"
    end

    test "an AGPL application marks its files as AGPL" do
      files = installed_files(license: "agpl", source_url: "https://example.com/sample")

      assert files["lib/sample_web/router.ex"] =~
               ~r/\A# SPDX-License-Identifier: AGPL-3.0-or-later\n/
    end

    @tag :tmp_dir
    test "the holder falls back to the git user name", %{tmp_dir: tmp_dir} do
      config = Path.join(tmp_dir, "gitconfig")
      env = [{"GIT_CONFIG_GLOBAL", config}, {"GIT_CONFIG_NOSYSTEM", "1"}]

      assert IthibatiStarter.git_user_name(cd: tmp_dir, env: env) == nil

      File.write!(config, "[user]\n  name = Git Author\n")
      assert IthibatiStarter.git_user_name(cd: tmp_dir, env: env) == "Git Author"
    end
  end

  test "locale support is wired in" do
    result = project() |> install()
    assert_creates(result, "lib/sample_web/locale.ex")
    assert diff(result, only: "config/config.exs") =~ "locales:"
    assert diff(result, only: "lib/sample_web/router.ex") =~ "plug SampleWeb.Locale"
    assert diff(result, only: "lib/sample_web/router.ex") =~ "{SampleWeb.Locale, :set}"

    assert diff(result, only: "lib/sample_web/components/layouts/root.html.heex") =~
             "assigns[:locale]"
  end

  # The files the generated license check covers; gettext catalogs are regenerated, vendor code is not ours.
  defp licensed?(path) do
    (String.match?(path, ~r{\A(lib|test|config|priv/repo|assets/js|assets/css|rel)/}) or
       path in ~w(mix.exs .formatter.exs .credo.exs .igniter.exs)) and
      not String.contains?(path, "/vendor/") and
      (Path.extname(path) in ~w(.ex .exs .heex .js .mjs .css) or
         String.starts_with?(path, "rel/overlays/bin/"))
  end

  # Generation needs a copyright holder; the Mix task falls back to git, these tests name one.
  defp install(igniter, opts \\ []) do
    IthibatiStarter.install(igniter, Keyword.put_new(opts, :copyright, "Sample Author"))
  end

  defp installed_files(opts \\ []) do
    project()
    |> install(opts)
    |> apply_igniter!()
    |> then(& &1.assigns.test_files)
  end
end
