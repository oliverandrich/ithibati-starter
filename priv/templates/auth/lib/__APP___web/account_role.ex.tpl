defmodule __MODULE__Web.AccountRole do
  @moduledoc """
  Keeps `current_account.admin` of an open page in step with the stored role.

  The gate loads the account once per mount. `__MODULE__.Accounts` broadcasts a grant or
  revocation, and this hook reads the role again into the assign. An administrator page whose
  account loses the role sends it to the settings. It is an `on_mount` hook of the `:members`
  live_session. The functions for an administrator still read the role from the database.
  """
  import Phoenix.Component, only: [update: 3]
  import Phoenix.LiveView, only: [attach_hook: 4, connected?: 1]

  alias __MODULE__.Accounts
  alias __MODULE__Web.Admin

  def on_mount(:follow, _params, _session, socket) do
    if connected?(socket) do
      Accounts.subscribe_role(socket.assigns.current_account)
      # A change between the gate's load and the subscription sent no message to this process.
      {:cont, socket |> reread() |> attach_hook(:account_role, :handle_info, &changed/2)}
    else
      {:cont, socket}
    end
  end

  defp changed(:role_changed, socket) do
    socket = reread(socket)
    revoked? = socket.assigns[:admin_page] && not socket.assigns.current_account.admin
    {:halt, if(revoked?, do: Admin.turn_away(socket), else: socket)}
  end

  defp changed(_message, socket), do: {:cont, socket}

  defp reread(socket) do
    admin = Accounts.admin?(socket.assigns.current_account)
    update(socket, :current_account, &%{&1 | admin: admin})
  end
end
