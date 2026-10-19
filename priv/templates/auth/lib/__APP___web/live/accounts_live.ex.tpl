defmodule __MODULE__Web.AccountsLive do
  @moduledoc """
  Lists every account for an administrator, with its creation date and role.
  """
  use __MODULE__Web, :live_view

  alias __MODULE__.Accounts
  alias __MODULE__Web.Admin

  on_mount {Admin, :require_admin}

  @impl true
  def mount(_params, _session, socket) do
    case Accounts.list_accounts(socket.assigns.current_account) do
      {:ok, accounts} -> {:ok, assign(socket, accounts: accounts)}
      # Only a role revoked between the hook and this read reaches here.
      {:error, :forbidden} -> {:ok, Admin.turn_away(socket)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.member
      flash={@flash}
      current_account={@current_account}
      section={:settings}
      title={gettext("Accounts")}
      back={%{to: ~p"/account/settings", label: gettext("Settings")}}
      breadcrumb
    >
      <.header>{gettext("Accounts")}</.header>
      <div class="mt-6 max-w-xl">
        <.group
          id="accounts"
          heading={ngettext("1 account", "%{count} accounts", length(@accounts))}
        >
          <div :for={account <- @accounts} id={"account-#{account.id}"} class="flex min-h-12 items-center gap-3 px-4 py-2">
            <div class="min-w-0 grow">
              <p class="truncate text-body text-ink">
                {account.username}
                <span :if={account.name} class="text-muted">· {account.name}</span>
              </p>
              <p class="text-meta text-muted">
                {gettext("Joined %{date}", date: Calendar.strftime(account.inserted_at, "%Y-%m-%d"))}
              </p>
            </div>
            <span :if={account.admin} class="text-meta font-semibold text-ink">{gettext("Administrator")}</span>
            <span :if={!account.admin} class="text-meta text-muted">{gettext("Member")}</span>
          </div>
        </.group>
      </div>
    </Layouts.member>
    """
  end
end
