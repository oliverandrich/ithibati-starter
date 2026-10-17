defmodule __MODULE__Web.InviteLive do
  @moduledoc """
  What somebody sees when they open an invitation link.

  The page shows the username the invitation was addressed to and does not offer to change it. That
  is not politeness: `Ithibati.Identity.Invitations.accept/2` checks that the account being created
  carries the identifier the invitation named, so a field here would only produce a refusal further
  down — and, until somebody noticed, a form that looks like it hands an invitation to whoever fills
  it in.
  """
  use __MODULE__Web, :live_view

  alias Ithibati.Identity.Invitations
  alias __MODULE__.Identity
  alias __MODULE__Web.CeremonyMessages

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    {:ok,
     assign(socket,
       token: token,
       invitation: Invitations.fetch(token),
       error: nil,
       email?: Identity.email?()
     )}
  end

  @impl true
  def handle_event("accept", _params, socket) do
    {:noreply, push_event(socket, "ithibati:register", %{token: socket.assigns.token})}
  end

  def handle_event("ithibati:failed", %{"error" => error} = payload, socket) do
    {:noreply, assign(socket, error: CeremonyMessages.message(error, payload["exception"]))}
  end

  def handle_event("ithibati:done", _payload, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.auth flash={@flash} title={gettext("You’re invited")}>
      <p :if={@invitation} class="mb-6 text-center text-sm text-muted">
        <span :if={not @email?}>
          {gettext("The account will be called %{username}.", username: @invitation.username)}
        </span>
        <span :if={@email?}>
          {gettext("The account will belong to %{address}.", address: @invitation.username)}
        </span>
      </p>

      <div :if={is_nil(@invitation)} role="alert" class="mt-6 rounded-control border border-danger bg-danger-surface p-4 text-label text-ink">
        <span>
          {gettext("This invitation has been used already, or it has expired. Ask for a new link.")}
        </span>
      </div>

      <div :if={@error} role="alert" class="mt-6 rounded-control border border-danger bg-danger-surface p-4 text-label text-ink"><span>{@error}</span></div>

      <p :if={@invitation} class="mt-6">
        <Layouts.auth_button phx-click="accept">{gettext("Accept with a passkey")}</Layouts.auth_button>
      </p>

      <Layouts.passkey_ceremony />
    </Layouts.auth>
    """
  end
end
