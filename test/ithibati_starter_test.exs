defmodule IthibatiStarterTest do
  use ExUnit.Case, async: true
  import Igniter.Test

  defp project do
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

    test_project(app_name: :sample, files: files)
  end

  test "default profile installs pinned invitation authentication and tooling" do
    result = project() |> IthibatiStarter.install()
    assert_has_task(result, "format", [])
    assert_creates(result, "lib/sample/accounts/invitation.ex")
    assert_creates(result, "lib/sample_web/live/sign_in_live.ex")
    assert_creates(result, "mise.toml", fn text -> assert text =~ "mix precommit" end)

    assert_creates(result, ".github/workflows/ci.yml", fn text ->
      assert text =~ "mise run check"
    end)

    assert diff(result, only: "mix.exs") =~ "== 0.4.0"
    assert diff(result, only: "mix.exs") =~ "ithibati.doctor"
    assert diff(result, only: "lib/sample_web/router.ex") =~ "ithibati_routes"
  end

  test "tooling-only profile omits auth dependencies, routes, migrations and browser tests" do
    result = project() |> IthibatiStarter.install(without_ithibati: true, without_beans: true)
    assert_creates(result, "mise.toml", fn text -> assert text =~ "mix precommit" end)
    assert diff(result, only: "mix.exs") =~ "credo"
    refute_creates(result, "lib/sample/accounts/user.ex")
    refute_creates(result, "test/features/invitation_test.exs")
    refute diff(result, only: "lib/sample_web/router.ex") =~ "ithibati_routes"
    refute diff(result) =~ "{:ithibati,"
    refute diff(result) =~ "{:wallaby,"
    refute diff(result) =~ "beans list"
  end

  test "reapplying the same profile preserves user edits and produces no changes" do
    installed = project() |> IthibatiStarter.install() |> apply_igniter!()
    result = installed |> IthibatiStarter.install()
    assert_unchanged(result)
  end

  test "flags cannot silently remove an installed authentication system" do
    project()
    |> IthibatiStarter.install()
    |> apply_igniter!()
    |> IthibatiStarter.install(without_ithibati: true)
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

  for opts <- [[], [without_ithibati: true, without_beans: true]] do
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

  for opts <- [[], [without_ithibati: true]] do
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
