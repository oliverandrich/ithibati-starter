defmodule __MODULE__Web.AccountsLive do
  @moduledoc """
  Lists every account for an administrator, with its creation date and role. An administrator
  grants or revokes the role on another account's row, or removes that account.

  Every change asks for a confirmation from the last five minutes; `docs/authentication.md` says
  why. The removed account's open pages are disconnected after the commit.
  """
  use __MODULE__Web, :live_view

  alias Ithibati.Web.Gate
  alias __MODULE__.Accounts
  alias __MODULE__Web.Admin
  alias __MODULE__Web.Reauth

  on_mount {Admin, :require_admin}

  @impl true
  def mount(_params, session, socket) do
    socket =
      assign(socket,
        removing: nil,
        # `Reauth.recent?/2` reads these on each change, so the five minutes still count then.
        confirmation: Map.take(session, ["confirmed_account_id", "confirmed_at"])
      )

    {:ok, listed(socket)}
  end

  @impl true
  def handle_event(role, %{"id" => id}, socket) when role in ["grant", "revoke"] do
    change = if role == "grant", do: &Accounts.grant_admin/2, else: &Accounts.revoke_admin/2

    if confirmed?(socket),
      do: {:noreply, changed(socket, change.(socket.assigns.current_account, id))},
      else: {:noreply, to_confirmation(socket)}
  end

  def handle_event("remove", %{"id" => id}, socket) do
    own = socket.assigns.current_account.id

    cond do
      not confirmed?(socket) ->
        {:noreply, to_confirmation(socket)}

      account = Enum.find(socket.assigns.accounts, &(to_string(&1.id) == id and &1.id != own)) ->
        {:noreply, assign(socket, removing: account)}

      true ->
        {:noreply, socket}
    end
  end

  def handle_event("cancel_remove", _params, socket), do: {:noreply, assign(socket, removing: nil)}

  def handle_event("confirm_remove", _params, %{assigns: %{removing: %{} = account}} = socket) do
    socket = assign(socket, removing: nil)

    with true <- confirmed?(socket) || :expired,
         {:ok, %{account: removed, digests: digests}} <-
           Accounts.remove_account(socket.assigns.current_account, account.id) do
      Gate.disconnect_sessions(socket.endpoint, digests)

      {:noreply,
       socket
       |> put_flash(:info, gettext("Removed %{username}.", username: removed.username))
       |> listed()}
    else
      :expired -> {:noreply, to_confirmation(socket)}
      error -> {:noreply, changed(socket, error)}
    end
  end

  def handle_event("confirm_remove", _params, socket), do: {:noreply, socket}

  defp confirmed?(socket),
    do: Reauth.recent?(socket.assigns.confirmation, socket.assigns.current_account)

  defp to_confirmation(socket), do: redirect(socket, to: ~p"/account/confirm/accounts")

  defp changed(socket, {:ok, _account}), do: listed(socket)
  defp changed(socket, {:error, :forbidden}), do: Admin.turn_away(socket)

  defp changed(socket, {:error, :last_admin}),
    do: put_flash(socket, :error, gettext("The last administrator keeps the role."))

  defp changed(socket, {:error, :not_found}),
    do: socket |> put_flash(:error, gettext("This account no longer exists.")) |> listed()

  defp changed(socket, {:error, _changeset}),
    do: put_flash(socket, :error, gettext("Nothing changed. Please try again."))

  defp listed(socket) do
    case Accounts.list_accounts(socket.assigns.current_account) do
      {:ok, accounts} -> assign(socket, accounts: accounts)
      # Only a role revoked between the hook and this read reaches here.
      {:error, :forbidden} -> Admin.turn_away(socket)
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
          <div :for={account <- @accounts} id={"account-#{account.id}"} class="flex flex-col gap-2 px-4 py-3 sm:flex-row sm:items-center sm:gap-3">
            <div class="min-w-0 grow">
              <p class="truncate text-body text-ink">
                {account.username}
                <span :if={account.name} class="text-muted">· {account.name}</span>
              </p>
              <p class="text-meta text-muted">
                {gettext("Joined %{date}", date: Calendar.strftime(account.inserted_at, "%Y-%m-%d"))}
                ·
                <span :if={account.admin} class="font-semibold text-ink">{gettext("Administrator")}</span>
                <span :if={!account.admin}>{gettext("Member")}</span>
              </p>
            </div>
            <%!-- The own row has no actions: removing oneself is a different question. --%>
            <%!-- The actions are as tall as a button on a phone, so a finger can hit them. --%>
            <div :if={account.id != @current_account.id} class="flex flex-wrap gap-x-4 text-label *:min-h-11 sm:*:min-h-6">
              <button :if={!account.admin} type="button" data-action="grant" phx-click="grant" phx-value-id={account.id} class="text-link">
                {gettext("Make administrator")}
              </button>
              <button :if={account.admin} type="button" data-action="revoke" phx-click="revoke" phx-value-id={account.id} class="text-link">
                {gettext("Revoke administrator")}
              </button>
              <button type="button" data-action="remove" phx-click="remove" phx-value-id={account.id} class="text-danger underline underline-offset-4">
                {gettext("Remove")}
              </button>
            </div>
          </div>
        </.group>
      </div>

      <.confirm_dialog
        :if={@removing}
        name="remove"
        title={gettext("Remove %{username}?", username: @removing.username)}
        confirm_label={gettext("Remove")}
        variant="danger"
      >
        {gettext("Their passkeys and recovery codes are deleted, and their open sessions end. This cannot be undone.")}
      </.confirm_dialog>
    </Layouts.member>
    """
  end
end
