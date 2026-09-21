defmodule __MODULE__Web.SignInLive do
  @moduledoc """
  The LiveView says *when* a ceremony starts; the hook does the round-trips.

  That split is not a style choice. A ceremony ends in a session cookie and a LiveView cannot set
  one, so the hook posts to the endpoints over `fetch` and follows the redirect the handler answers
  with. What a LiveView is good at — validating the fields before any of that begins — is what it
  does here.
  """
  use __MODULE__Web, :live_view

  alias Ithibati.Identity.Instance
  alias __MODULE__.Identity
  alias __MODULE__Web.CeremonyMessages

  @impl true
  def mount(_params, session, socket) do
    setup_authorized? =
      socket.assigns.live_action == :setup and
        Instance.authorized?(session["initial_setup_authorization"])
    {:ok,
     assign(socket,
       username: "",
       error: nil,
       setup_authorized?: setup_authorized?,
       email?: Identity.email?()
     )}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    needs_setup? = Instance.needs_setup?()

    cond do
      socket.assigns.current_account ->
        {:noreply, redirect(socket, to: ~p"/")}

      needs_setup? and socket.assigns.live_action != :setup ->
        {:noreply, redirect(socket, to: ~p"/setup")}

      not needs_setup? and socket.assigns.live_action == :setup ->
        {:noreply, redirect(socket, to: ~p"/login")}

      true ->
        {:noreply, assign(socket, error: nil)}
    end
  end

  @impl true
  def handle_event("validate", %{"username" => username}, socket) do
    {:noreply, assign(socket, username: username, error: nil)}
  end

  def handle_event("register", %{"username" => username}, socket) do
    # Pushed to the hook, which takes it from here.
    {:noreply,
     socket |> assign(error: nil) |> push_event("ithibati:register", %{username: username})}
  end

  def handle_event("sign-in", _params, socket) do
    {:noreply, socket |> assign(error: nil) |> push_event("ithibati:authenticate", %{})}
  end

  def handle_event("recover", %{"code" => code}, socket) do
    {:noreply, socket |> assign(error: nil) |> push_event("ithibati:recover", %{code: code})}
  end

  # What the hook pushes back. A successful ceremony ends in the redirect the handler answered with,
  # so the only thing that reaches the LiveView is a failure.
  def handle_event("ithibati:failed", %{"error" => error} = payload, socket) do
    {:noreply, assign(socket, error: CeremonyMessages.message(error, payload["exception"]))}
  end

  def handle_event("ithibati:done", _payload, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.auth flash={@flash} title={title(@live_action)} subtitle={subtitle(@live_action, @email?)}>
      <div :if={@error} role="alert" class="mb-6 rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-800 dark:border-red-900 dark:bg-red-950 dark:text-red-200">{@error}</div>

      <div :if={@live_action == :login}>
        <h1 class="sr-only">{gettext("Sign in")}</h1>
        <Layouts.auth_button phx-click="sign-in">{gettext("Sign in with a passkey")}</Layouts.auth_button>
        <p class="mt-6 text-center text-sm">
          <.link navigate={~p"/recover"} class="text-violet-600 underline-offset-4 hover:underline dark:text-violet-400">{gettext("Lost your passkey? Use a recovery code")}</.link>
        </p>
      </div>

      <.form :if={@live_action == :setup and not @setup_authorized?} for={%{}} id="setup-code-form" action={~p"/setup/authorize"}>
        <.input type="password" name="setup_code" value="" label={gettext("Setup code")} autocomplete="off" required />
        <Layouts.auth_button>{gettext("Unlock setup")}</Layouts.auth_button>
      </.form>

      <form :if={@live_action == :setup and @setup_authorized?} id="claim-form" phx-change="validate" phx-submit="register">
        <Layouts.identifier_input value={@username} />
        <Layouts.auth_button>{gettext("Create your passkey")}</Layouts.auth_button>
      </form>

      <div :if={@live_action == :recover}>
        <form id="recovery-form" phx-submit="recover" phx-auto-recover="ignore">
          <.input name="code" value="" label={gettext("Recovery code")} autocomplete="off" spellcheck="false" required />
          <Layouts.auth_button>{gettext("Sign in with a recovery code")}</Layouts.auth_button>
        </form>
        <p class="mt-6 text-center text-sm">
          <.link navigate={~p"/login"} class="text-violet-600 underline-offset-4 hover:underline dark:text-violet-400">{gettext("Back to passkey sign-in")}</.link>
        </p>
      </div>

      <Layouts.passkey_ceremony />
    </Layouts.auth>
    """
  end

  defp title(:login), do: nil
  defp title(:setup), do: gettext("Make yourself at home")
  defp title(:recover), do: gettext("Use a recovery code")

  defp subtitle(:login, _email?), do: nil

  defp subtitle(:setup, true),
    do: gettext("Enter the operator setup code, then your email address, and create a passkey.")

  defp subtitle(:setup, false),
    do: gettext("Enter the operator setup code, then choose your username and create a passkey.")

  defp subtitle(:recover, _email?), do: gettext("Enter one of the codes you saved when you set up your account. Each code works once.")
end
