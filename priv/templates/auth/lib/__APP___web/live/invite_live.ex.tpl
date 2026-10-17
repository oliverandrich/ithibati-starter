defmodule __MODULE__Web.InviteLive do
  @moduledoc """
  What somebody sees when they open an invitation link.

  The token is in the link's fragment, which no request sends. `assets/js/invitation_link.js`
  removes it from the address before the socket joins. The hook pushes it after the join.
  Until then the page shows a waiting line.

  An addressed invitation shows its identifier and offers no field to change it.
  `Ithibati.Identity.Invitations.accept/3` refuses an account under another identifier.
  An open invitation names nobody, so the invitee chooses the username here.
  """
  use __MODULE__Web, :live_view

  alias Ithibati.Identity.Invitations
  alias __MODULE__.Identity
  alias __MODULE__Web.CeremonyMessages

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       status: :waiting,
       token: nil,
       invitation: nil,
       username: "",
       error: nil,
       email?: Identity.email?()
     )}
  end

  @impl true
  # One token per page, so a socket cannot ask about token after token.
  def handle_event("invitation-token", %{"token" => token}, %{assigns: %{status: :waiting}} = socket) do
    invitation = Invitations.fetch(token)

    socket =
      assign(socket, token: token, invitation: invitation, status: status(invitation), error: nil)

    # The tab keeps the token for a reload. One that opens nothing is dropped there too.
    {:noreply, if(invitation, do: socket, else: push_event(socket, "invitation-token-forget", %{}))}
  end

  def handle_event("invitation-token", _params, socket), do: {:noreply, socket}

  def handle_event("validate", %{"username" => username}, socket) do
    {:noreply, assign(socket, username: username, error: nil)}
  end

  def handle_event("accept", params, socket) do
    identity =
      case socket.assigns.status do
        :open -> %{token: socket.assigns.token, username: params["username"]}
        _addressed -> %{token: socket.assigns.token}
      end

    {:noreply, socket |> assign(error: nil) |> push_event("ithibati:register", identity)}
  end

  def handle_event("ithibati:failed", %{"error" => error} = payload, socket) do
    {:noreply, assign(socket, error: CeremonyMessages.message(error, payload["exception"]))}
  end

  def handle_event("ithibati:done", _payload, socket), do: {:noreply, socket}

  defp status(nil), do: :unknown
  defp status(invitation), do: if(Invitations.open?(invitation), do: :open, else: :addressed)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.auth flash={@flash} title={gettext("You’re invited")}>
      <div id="invitation-link" phx-hook="InvitationLink"></div>

      <p :if={@status == :waiting} class="text-center text-sm text-muted">
        {gettext("Opening your invitation…")}
      </p>

      <p :if={@status == :addressed} class="mb-6 text-center text-sm text-muted">
        <span :if={not @email?}>
          {gettext("The account will be called %{username}.", username: @invitation.username)}
        </span>
        <span :if={@email?}>
          {gettext("The account will belong to %{address}.", address: @invitation.username)}
        </span>
      </p>

      <.alert :if={@status == :unknown} class="mt-6">
        {gettext("This invitation has been used already, or it has expired. Ask for a new link.")}
      </.alert>

      <.alert :if={@error} class="mt-6">{@error}</.alert>

      <p :if={@status == :addressed} class="mt-6">
        <Layouts.auth_button phx-click="accept">{gettext("Accept with a passkey")}</Layouts.auth_button>
      </p>

      <form :if={@status == :open} id="invitation-accept-form" phx-change="validate" phx-submit="accept">
        <p class="mb-6 text-center text-sm text-muted">
          {gettext("Choose your username, then create a passkey.")}
        </p>
        <Layouts.identifier_input value={@username} />
        <Layouts.auth_button>{gettext("Accept with a passkey")}</Layouts.auth_button>
      </form>

      <Layouts.passkey_ceremony />
    </Layouts.auth>
    """
  end
end
