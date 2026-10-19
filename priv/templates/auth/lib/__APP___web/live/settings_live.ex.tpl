defmodule __MODULE__Web.SettingsLive do
  @moduledoc """
  The account's settings in grouped cards. Each row leads to the page that changes it.
  """
  use __MODULE__Web, :live_view

  alias Ithibati.Identity.Passkeys
  alias Ithibati.Identity.RecoveryCodes

  @impl true
  def mount(_params, _session, socket) do
    account = socket.assigns.current_account

    {:ok,
     assign(socket,
       passkeys: length(Passkeys.list_keys(account)),
       codes: RecoveryCodes.remaining(account)
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.member
      flash={@flash}
      current_account={@current_account}
      section={:settings}
      title={gettext("Settings")}
    >
      <.header>{gettext("Settings")}</.header>
      <div class="mt-6 max-w-xl">
        <.group id="settings-account" heading={gettext("Account & security")} tag="nav">
          <.group_link to={~p"/account/passkeys"} detail={@passkeys}>{gettext("Passkeys")}</.group_link>
          <.group_link to={~p"/account/recovery-codes"} detail={ngettext("1 left", "%{count} left", @codes)}>
            {gettext("Recovery codes")}
          </.group_link>
          <.group_link to={~p"/account/invitations"}>{gettext("Invitations")}</.group_link>
        </.group>
        <.group :if={@current_account.admin} id="settings-admin" heading={gettext("Administration")} tag="nav">
          <.group_link to={~p"/accounts"}>{gettext("Accounts")}</.group_link>
        </.group>
      </div>
    </Layouts.member>
    """
  end
end
