defmodule IthibatiStarterTest do
  use ExUnit.Case, async: true
  import Igniter.Test
  alias Mix.Tasks.IthibatiStarter.Install

  # The scaffold `phx.new` writes with a mailer, which is the only one the installer accepts:
  # the second directory holds the files that differ from the plain one and wins where both have
  # the same path.
  @fixtures ["test/fixtures/phoenix", "test/fixtures/phoenix_mailer"]

  defp project do
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

    test_project(app_name: :sample, files: files)
  end

  for opts <- [[], [without_beans: true]] do
    @documentation_opts opts
    @tag :documentation
    test "documentation separates contribution workflow from application guides for #{inspect(opts)}" do
      result = project() |> IthibatiStarter.install(@documentation_opts) |> apply_igniter!()
      files = result.assigns.test_files

      assert files["docs/operations.md"] =~ "bin/migrate"
      assert files["docs/operations.md"] =~ "bin/setup-code"
      assert files["docs/operations.md"] =~ "Sample.AuthCleanup.run()"
      assert files["docs/authentication.md"] =~ "invite: {20, 86_400}"
      assert files["docs/authentication.md"] =~ "initial_claim: :operator_code"
      assert files["docs/operations.md"] =~ "TRUSTED_PROXIES"
      assert files["docs/authentication.md"] =~ "[Operations](operations.md)"
      assert files["docs/localization.md"] =~ "Accept-Language"
      assert files["CONTRIBUTING.md"] =~ "Chrome"
      refute files["CONTRIBUTING.md"] =~ "## Authentication limits"
      refute files["CONTRIBUTING.md"] =~ "## Health, releases"
      assert files["README.md"] =~ "docs/operations.md"
      assert files["README.md"] =~ "Ithibati Starter 0.4.0"
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

      result |> IthibatiStarter.install(@documentation_opts) |> assert_unchanged()
    end
  end

  test "default profile installs pinned invitation authentication and tooling" do
    result = project() |> IthibatiStarter.install()
    assert Mix.Project.config()[:version] == "0.4.0"

    assert_creates(result, ".ithibati-starter", fn text ->
      assert String.starts_with?(text, "0.4.0\n")
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
    assert diff(result, only: "mix.exs") =~ ~s({:ithibati, "~> 0.5.0"})
    assert diff(result, only: "mix.exs") =~ "ithibati.doctor"
    assert diff(result, only: "lib/sample_web/router.ex") =~ "ithibati_routes"
    assert diff(result, only: "config/config.exs") =~ ~s("setup_code")
  end

  test "generated protected claim uses Ithibati schema version 3" do
    files =
      project() |> IthibatiStarter.install() |> apply_igniter!() |> then(& &1.assigns.test_files)

    assert files["config/config.exs"] =~ "initial_claim: :operator_code"

    assert files["priv/repo/migrations/20260920000000_add_setup_codes.exs"] =~
             "Ithibati.Migration.up(from: 2, version: 3)"

    refute Map.has_key?(
             files,
             "priv/repo/migrations/20260919000000_create_initial_setup_codes.exs"
           )

    assert files["lib/sample_web/auth.ex"] =~ "Instance.claim(authorization: authorization)"
    refute files["lib/sample_web/auth.ex"] =~ "InitialSetup.consume"
  end

  test "an unsupported claim mode stops the boot instead of offering a field nobody can satisfy" do
    files =
      project() |> IthibatiStarter.install() |> apply_igniter!() |> then(& &1.assigns.test_files)

    assert files["lib/sample/claim.ex"] =~ "Config.initial_claim_mode()"
    assert files["lib/sample/claim.ex"] =~ ":operator_code"
    assert Map.has_key?(files, "test/sample/claim_test.exs")

    assert [_, started] = String.split(files["lib/sample/application.ex"], "Claim.verify!()")
    assert started =~ "children = ["

    assert files["lib/sample/initial_setup.ex"] =~ "Claim.verify!()"
  end

  test "a request forwarded by a trusted proxy is counted against the visitor" do
    files =
      project() |> IthibatiStarter.install() |> apply_igniter!() |> then(& &1.assigns.test_files)

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
    assert files["config/runtime.exs"] =~ ":inet.parse_strict_address"
    assert Map.has_key?(files, "test/sample_web/trusted_proxies_test.exs")
  end

  @tag :command_contract
  test "mise exposes development, reset and release commands" do
    result = project() |> IthibatiStarter.install()

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
    result = project() |> IthibatiStarter.install() |> apply_igniter!()
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

  test "there is one profile left, and Beans is the only thing still optional" do
    info = Install.info([], nil)
    refute Keyword.has_key?(info.schema, :with_mail)
    refute Keyword.has_key?(info.schema, :without_ithibati)
    assert info.schema[:without_beans] == :boolean

    result = project() |> IthibatiStarter.install(without_beans: true)
    assert_creates(result, "lib/sample/accounts/user.ex")
    refute_creates(result, ".beans.yml")
    refute diff(result, only: "mise.toml") =~ "beans list"
  end

  test "an account is named or addressed, and the instance decides at runtime" do
    result = project() |> IthibatiStarter.install()
    assert_creates(result, "lib/sample/identity.ex")
    assert_creates(result, "lib/sample_web/invitation_mail.ex")
    assert_creates(result, "test/sample/identity_test.exs")

    assert diff(result, only: "config/runtime.exs") =~ "ACCOUNT_IDENTITY"
    assert diff(result, only: "config/runtime.exs") =~ "MAIL_ENABLED"
    # 465 is implicit TLS and 587 is STARTTLS; neither is hardcoded against the other's port.
    assert diff(result, only: "config/runtime.exs") =~ "smtp_port == 465"

    files = result |> apply_igniter!() |> then(& &1.assigns.test_files)

    # The library binds the identifier field when it compiles, so the shape is all that is left
    # to choose, and neither schema may fix it.
    for schema <- ["lib/sample/accounts/user.ex", "lib/sample/accounts/invitation.ex"] do
      refute files[schema] =~ "format:", schema
      assert files[schema] =~ "Identity.validate()", schema
    end

    assert [_, started] = String.split(files["lib/sample/application.ex"], "Identity.verify!()")
    assert started =~ "children = ["
  end

  test "every application ships the mailer, and the Phoenix one is adopted rather than replaced" do
    original = project()
    result = IthibatiStarter.install(original)
    assert diff(result, only: "mix.exs") =~ ":swoosh"
    assert diff(result, only: "lib/sample_web/router.ex") =~ "MailboxPreview"

    installed = apply_igniter!(result)
    files = installed.assigns.test_files

    # Phoenix already configures both adapters; what matters is that they survive.
    assert files["config/dev.exs"] =~ "Swoosh.Adapters.Local"
    assert files["config/test.exs"] =~ "Swoosh.Adapters.Test"
    assert files["config/dev.exs"] =~ "mail_enabled: true"

    # Phoenix wrote the module and the starter leaves it exactly as it found it.
    assert files["lib/sample/mailer.ex"] ==
             original.assigns.test_files["lib/sample/mailer.ex"]

    assert files["config/prod.exs"] =~ "api_client: false"
    refute files["config/prod.exs"] =~ "Swoosh.ApiClient.Req"

    assert length(Regex.scan(~r/Plug.Swoosh.MailboxPreview/, files["lib/sample_web/router.ex"])) ==
             1

    assert length(Regex.scan(~r/\{:swoosh,/, files["mix.exs"])) == 1
    installed |> IthibatiStarter.install() |> assert_unchanged()
  end

  test "a customized router with a Phoenix mailbox is still refused" do
    project()
    |> IthibatiStarter.Files.replace(
      "lib/sample_web/router.ex",
      "PageController, :home",
      "PageController, :custom"
    )
    |> apply_igniter!()
    |> IthibatiStarter.install()
    |> assert_has_issue(&String.contains?(&1, "router"))
    |> assert_unchanged()
  end

  test "reapplying the same profile preserves user edits and produces no changes" do
    installed = project() |> IthibatiStarter.install() |> apply_igniter!()
    result = installed |> IthibatiStarter.install()
    assert_unchanged(result)
  end

  test "an installed profile from another version is not converted in silence" do
    project()
    |> IthibatiStarter.install()
    |> apply_igniter!()
    |> IthibatiStarter.Files.replace(".ithibati-starter", "0.4.0", "0.3.0")
    |> apply_igniter!()
    |> IthibatiStarter.install()
    |> assert_has_issue(&String.contains?(&1, "profile"))
  end

  test "non-Phoenix projects are refused before making changes" do
    result = test_project() |> IthibatiStarter.install()
    assert_has_issue(result, &String.contains?(&1, "Phoenix"))
    assert_unchanged(result)
  end

  test "existing tooling is refused instead of overwritten" do
    result =
      project()
      |> Igniter.create_new_file("mise.toml", "# My existing tooling\n")
      |> apply_igniter!()
      |> IthibatiStarter.install()

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
      |> IthibatiStarter.install()

    assert_has_issue(result, &String.contains?(&1, "binary_id"))
    assert_unchanged(result)
  end

  test "applying the installer keeps HTML modules beside their embedded templates" do
    result = project() |> IthibatiStarter.install() |> apply_igniter!()
    assert Map.has_key?(result.assigns.test_files, "lib/sample_web/controllers/session_html.ex")
    assert Map.has_key?(result.assigns.test_files, "test/features/invitation_test.exs")
  end

  test "template aliases remain ordered for application names before Ithibati" do
    source = "  alias Ithibati.Identity.Grant\n  alias __MODULE__.Repo\n"

    assert IthibatiStarter.Files.render(source, %{app: "acme", module: "Acme"}) ==
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
      |> IthibatiStarter.install()

    assert_has_issue(result, &String.contains?(&1, "router"))
    assert_unchanged(result)
  end

  test "checks explicitly select the test environment even when the shell selects dev" do
    result = project() |> IthibatiStarter.install()

    assert_creates(result, "mise.toml", fn text ->
      assert text =~ "env.MIX_ENV = \"test\""
    end)
  end

  for opts <- [[], [without_beans: true]] do
    @profile_opts opts
    test "Lucide replaces Heroicons in profile #{inspect(opts)}" do
      planned = project() |> IthibatiStarter.install(@profile_opts)
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
      installed = project() |> IthibatiStarter.install(@profile_opts) |> apply_igniter!()
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
      assert files["lib/sample_web/components/layouts/root.html.heex"] =~ "dark:bg-"
    end
  end

  test "locale support is wired in" do
    result = project() |> IthibatiStarter.install()
    assert_creates(result, "lib/sample_web/locale.ex")
    assert diff(result, only: "config/config.exs") =~ "locales:"
    assert diff(result, only: "lib/sample_web/router.ex") =~ "plug SampleWeb.Locale"
    assert diff(result, only: "lib/sample_web/router.ex") =~ "{SampleWeb.Locale, :set}"

    assert diff(result, only: "lib/sample_web/components/layouts/root.html.heex") =~
             "assigns[:locale]"
  end
end
