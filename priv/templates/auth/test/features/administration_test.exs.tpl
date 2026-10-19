defmodule __MODULE__Web.AdministrationFeatureTest do
  use __MODULE__Web.FeatureCase

  alias __MODULE__.Accounts.User
  alias __MODULE__.Repo

  defp dialog_open?(session),
    do: execute_script(session, "return document.querySelector('#remove-confirm')?.matches(':modal') === true", [], &send(self(), {:open, &1}))

  defp focused(session),
    do: execute_script(session, "return document.activeElement.dataset.action || ''", [], &send(self(), {:focused, &1}))

  feature "an administrator confirms the passkey and opens the removal dialog", %{session: session} do
    virtual_authenticator(session)

    session
    |> unlock_setup()
    |> fill_in(css("input[name=username]"), with: "ada")
    |> click(button("Create your passkey"))
    |> landed_on("/recovery-codes")

    grace = Repo.insert!(%User{username: "grace"})

    session
    |> open("/accounts")
    |> connected()
    |> click(css("#account-#{grace.id} [data-action=remove]"))
    |> landed_on("/account/verify")
    |> connected()
    |> click(button("Confirm with a passkey"))
    |> landed_on("/accounts")
    |> connected()
    |> click(css("#account-#{grace.id} [data-action=remove]"))
    |> assert_has(css("#remove-confirm", text: "Remove grace?"))
    |> dialog_open?()

    assert_receive {:open, true}

    # The LiveView test covers cancel and confirm. In the browser, LiveView sometimes leaves a
    # click unanswered that follows the opening within milliseconds.
    session
    |> send_keys([:escape])
    |> refute_has(css("#remove-confirm"))
    |> focused()

    assert_receive {:focused, "remove"}
    assert Repo.get(User, grace.id)
  end
end
