defmodule IthibatiStarterTest do
  use ExUnit.Case, async: true
  import Igniter.Test
  alias Mix.Tasks.IthibatiStarter.Install

  defp project(with_mailer \\ false) do
    files =
      "test/fixtures/phoenix/**/*.txt"
      |> Path.wildcard(match_dot: true)
      |> Map.new(fn path ->
        {path |> Path.relative_to("test/fixtures/phoenix") |> String.trim_trailing(".txt"),
         File.read!(path)}
      end)
      |> Map.put(
        ".formatter.exs",
        "[locals_without_parens: [embed_templates: 1, plug: 1, plug: 2], inputs: [\"**/*.{ex,exs}\"]]"
      )

    files =
      if with_mailer do
        "test/fixtures/phoenix_mailer/**/*.txt"
        |> Path.wildcard()
        |> Enum.reduce(files, fn path, acc ->
          Map.put(
            acc,
            path
            |> Path.relative_to("test/fixtures/phoenix_mailer")
            |> String.trim_trailing(".txt"),
            File.read!(path)
          )
        end)
      else
        files
      end

    test_project(app_name: :sample, files: files)
  end

  for opts <- [[], [with_mail: true, without_beans: true]] do
    @documentation_opts opts
    @tag :documentation
    test "documentation separates contribution workflow from application guides for #{inspect(opts)}" do
      result = project() |> IthibatiStarter.install(@documentation_opts) |> apply_igniter!()
      files = result.assigns.test_files

      assert files["docs/operations.md"] =~ "bin/migrate"
      assert files["docs/operations.md"] =~ "bin/setup-code"
      assert files["docs/operations.md"] =~ "Sample.AuthCleanup.run()"
      assert files["docs/authentication.md"] =~ "manual_invitation: {10, 3600}"
      assert files["docs/authentication.md"] =~ "initial_claim: :operator_code"
      assert files["docs/operations.md"] =~ "TRUSTED_PROXIES"
      assert files["docs/authentication.md"] =~ "[Operations](operations.md)"
      assert files["docs/localization.md"] =~ "Accept-Language"
      assert files["CONTRIBUTING.md"] =~ "Chrome"
      refute files["CONTRIBUTING.md"] =~ "## Authentication limits"
      refute files["CONTRIBUTING.md"] =~ "## Health, releases"
      assert files["README.md"] =~ "docs/operations.md"
      assert files["README.md"] =~ "Ithibati Starter 0.3.0"
      assert files["README.md"] =~ "mise run setup-code"
      assert files["AGENTS.md"] =~ "Documentation structure"
      refute Map.has_key?(files, "docs/development.md")

      if @documentation_opts[:with_mail] do
        assert files["docs/mail.md"] =~ "SMTP_HOST"
        assert files["docs/mail.md"] =~ "separate from the manual-link"
        assert files["README.md"] =~ "docs/mail.md"
        assert files["docs/authentication.md"] =~ "(mail.md)"
        refute files["CONTRIBUTING.md"] =~ "SMTP_HOST"
      else
        refute Map.has_key?(files, "docs/mail.md")
        refute files["README.md"] =~ "docs/mail.md"
      end

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
    assert Mix.Project.config()[:version] == "0.3.0"

    assert_creates(result, ".ithibati-starter", fn text ->
      assert String.starts_with?(text, "0.3.0\n")
    end)

    assert_has_task(result, "format", [])
    assert_creates(result, "lib/sample/accounts/invitation.ex")
    assert_creates(result, "lib/sample_web/live/sign_in_live.ex")
    assert_creates(result, "mise.toml", fn text -> assert text =~ "mix precommit" end)

    assert_creates(result, ".github/workflows/ci.yml", fn text ->
      assert text =~ "mise run check"
    end)

    assert diff(result, only: "mix.exs") =~ "== 0.5.0"
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

  for opts <- [[], [with_mail: true]] do
    @command_opts opts
    @tag :command_contract
    test "mise exposes development, reset and release commands for #{inspect(opts)}" do
      result = project() |> IthibatiStarter.install(@command_opts)

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
    test "release launchers start the server, migrate and issue setup codes from any directory for #{inspect(opts)}" do
      result = project() |> IthibatiStarter.install(@command_opts) |> apply_igniter!()
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
  end

  test "mail is opt-in and Ithibati can no longer be omitted" do
    info = Install.info([], nil)
    assert info.schema[:with_mail] == :boolean
    refute Keyword.has_key?(info.schema, :without_ithibati)
    result = project() |> IthibatiStarter.install(without_beans: true)
    refute_creates(result, "lib/sample/mailer.ex")
    refute diff(result) =~ "{:swoosh,"
    assert_creates(result, "lib/sample/accounts/user.ex")
    refute_creates(result, ".beans.yml")
    refute diff(result, only: "mise.toml") =~ "beans list"
  end

  test "mail profile generates delivery, preview, configuration and tests" do
    result = project() |> IthibatiStarter.install(with_mail: true)
    assert_creates(result, "lib/sample/mailer.ex")
    assert_creates(result, "lib/sample/invitations.ex")
    assert_creates(result, "lib/sample_web/controllers/invitation_controller.ex")
    assert_creates(result, "test/sample_web/invitation_mail_test.exs")
    assert diff(result, only: "mix.exs") =~ ":swoosh"
    assert diff(result, only: "config/dev.exs") =~ "Swoosh.Adapters.Local"
    assert diff(result, only: "config/test.exs") =~ "Swoosh.Adapters.Test"
    assert diff(result, only: "config/runtime.exs") =~ "SMTP_HOST"
    assert diff(result, only: "lib/sample_web/router.ex") =~ "MailboxPreview"
    result |> apply_igniter!() |> IthibatiStarter.install(with_mail: true) |> assert_unchanged()
  end

  test "mail profile adopts the Phoenix mailer and replaces its production API client" do
    original = project(true)
    installed = original |> IthibatiStarter.install(with_mail: true) |> apply_igniter!()
    files = installed.assigns.test_files
    assert files["lib/sample/mailer.ex"] == original.assigns.test_files["lib/sample/mailer.ex"]
    assert files["lib/sample/invitations.ex"] =~ "InvitationMail.deliver"
    assert files["config/prod.exs"] =~ "api_client: false"
    refute files["config/prod.exs"] =~ "Swoosh.ApiClient.Req"

    assert length(Regex.scan(~r/Plug.Swoosh.MailboxPreview/, files["lib/sample_web/router.ex"])) ==
             1

    assert length(Regex.scan(~r/\{:swoosh,/, files["mix.exs"])) == 1
    installed |> IthibatiStarter.install(with_mail: true) |> assert_unchanged()
  end

  test "a customized router with a Phoenix mailbox is still refused" do
    project(true)
    |> IthibatiStarter.Files.replace(
      "lib/sample_web/router.ex",
      "PageController, :home",
      "PageController, :custom"
    )
    |> apply_igniter!()
    |> IthibatiStarter.install(with_mail: true)
    |> assert_has_issue(&String.contains?(&1, "router"))
    |> assert_unchanged()
  end

  test "reapplying the same profile preserves user edits and produces no changes" do
    installed = project() |> IthibatiStarter.install() |> apply_igniter!()
    result = installed |> IthibatiStarter.install()
    assert_unchanged(result)
  end

  test "mail profile cannot silently replace an installed profile" do
    project()
    |> IthibatiStarter.install()
    |> apply_igniter!()
    |> IthibatiStarter.install(with_mail: true)
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

  for opts <- [[], [with_mail: true, without_beans: true]] do
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

  for opts <- [[], [with_mail: true]] do
    @locale_opts opts
    test "locale support is wired into profile #{inspect(opts)}" do
      result = project() |> IthibatiStarter.install(@locale_opts)
      assert_creates(result, "lib/sample_web/locale.ex")
      assert diff(result, only: "config/config.exs") =~ "locales:"
      assert diff(result, only: "lib/sample_web/router.ex") =~ "plug SampleWeb.Locale"
      assert diff(result, only: "lib/sample_web/router.ex") =~ "{SampleWeb.Locale, :set}"

      assert diff(result, only: "lib/sample_web/components/layouts/root.html.heex") =~
               "assigns[:locale]"
    end
  end
end
