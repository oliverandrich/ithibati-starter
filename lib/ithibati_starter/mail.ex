defmodule IthibatiStarter.Mail do
  @moduledoc false
  alias Igniter.Project.Config
  alias Igniter.Project.Deps
  alias IthibatiStarter.Files

  def install(igniter, b) do
    app = String.to_atom(b.app)
    mailer = Module.concat([b.module, Mailer])

    igniter
    |> Deps.add_dep({:swoosh, "~> 1.28"}, yes?: true)
    |> Deps.add_dep({:gen_smtp, "~> 1.3"}, yes?: true)
    |> Files.copy_tree("mail", b)
    |> Igniter.create_new_file("lib/#{b.app}/mailer.ex", Files.template("fragments/mailer", b),
      on_exists: :skip
    )
    |> Config.configure("config.exs", :swoosh, [:api_client], false)
    |> Config.configure("config.exs", app, [:mail_from], {b.module, "invitations@example.test"})
    |> Config.configure("dev.exs", app, [mailer, :adapter], Swoosh.Adapters.Local)
    |> Config.configure("test.exs", app, [mailer, :adapter], Swoosh.Adapters.Test)
    |> Config.configure("test.exs", :swoosh, [:local], false)
    |> Config.configure("prod.exs", :swoosh, [:local], false)
    |> Config.configure("prod.exs", :swoosh, [:api_client], false)
    |> Files.append("config/runtime.exs", Files.template("fragments/mail_runtime", b))
    |> Igniter.create_new_file("lib/#{b.app}_web/router.ex", router(b), on_exists: :overwrite)
    |> Files.replace(
      "lib/#{b.app}_web/live/inside_live.ex",
      "    </Layouts.member>",
      Files.template("fragments/mail_form", b) <> "\n    </Layouts.member>"
    )
    |> Files.append("CONTRIBUTING.md", Files.template("fragments/mail_docs", b))
  end

  defp router(b) do
    Files.template("fragments/router", b)
    |> String.replace(
      "    post \"/recovery-codes\",",
      "    post \"/invitations\", InvitationController, :create\n    post \"/recovery-codes\","
    )
    |> String.replace(
      "  pipeline :authenticated do",
      Files.template("fragments/mail_routes", b) <> "\n  pipeline :authenticated do"
    )
  end
end
