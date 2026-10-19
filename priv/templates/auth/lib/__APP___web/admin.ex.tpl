defmodule __MODULE__Web.Admin do
  @moduledoc """
  The `on_mount` hook of the administrator pages.

  The pages live in the members' live_session and declare the hook with `on_mount/1`. It then
  runs after Ithibati's gate has assigned `current_account`. It reads the account loaded for
  this mount. The functions for an administrator in `__MODULE__.Accounts` check the role again.
  """
  use __MODULE__Web, :verified_routes
  use Gettext, backend: __MODULE__Web.Gettext

  import Phoenix.LiveView, only: [put_flash: 3, redirect: 2]

  # Anything but an administrator is turned away, including a page without an account.
  def on_mount(:require_admin, _params, _session, socket) do
    case socket.assigns[:current_account] do
      %{admin: true} -> {:cont, socket}
      _other -> {:halt, turn_away(socket)}
    end
  end

  @doc "Sends a member to the settings with a message."
  def turn_away(socket) do
    socket
    |> put_flash(:error, gettext("Only administrators can open this page."))
    |> redirect(to: ~p"/account/settings")
  end
end
