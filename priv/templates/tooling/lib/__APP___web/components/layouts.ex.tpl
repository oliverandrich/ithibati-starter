defmodule __MODULE__Web.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use __MODULE__Web, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  alias __MODULE__.Identity

  @doc """
  The element the passkey hook attaches to.

  It renders nothing — it exists so the hook has somewhere to live and somewhere to read the four
  ceremony paths from, which are yours because you chose the scope `ithibati_routes/1` is mounted
  under. Both pages here that can start a ceremony render it, so the paths are written once: a
  second copy is a second place to forget when that scope moves.
  """
  def passkey_ceremony(assigns) do
    ~H"""
    <div
      id="passkey"
      phx-update="ignore"
      phx-hook="Ithibati.Web.Hooks.PasskeyCeremony"
      data-registration-challenge-url={~p"/auth/registration/challenge"}
      data-registration-url={~p"/auth/registration"}
      data-authentication-challenge-url={~p"/auth/authentication/challenge"}
      data-recovery-url={~p"/auth/recovery"}
      data-authentication-url={~p"/auth/authentication"}
    >
    </div>
    """
  end

  @doc """
  What an identifier may look like, for the browser to check before the server does.

  Derived from the shape this instance actually asks for rather than written out beside it: an
  HTML `pattern` that disagrees with the server refuses names the server would take, or waves
  through names it will not, and nothing says so. The anchors come off because `pattern` is
  implicitly anchored and its grammar has no `\\A`.

  An address gets no pattern. `type="email"` is the browser's own check for one, and the email
  grammar does not survive the trip into `pattern` intact.
  """
  def identifier_pattern do
    if Identity.email?(),
      do: nil,
      else: Identity.format() |> Regex.source() |> String.replace(["\\A", "\\z"], "")
  end

  @doc """
  The field an account is identified by, asked for the way this instance means it.

  One component rather than a pair of `:if`-gated inputs in every screen that asks. The two
  halves differ in more than a label, and spelling them out per screen is how one of them ends
  up without an `autocomplete` while the other has one.
  """
  attr :value, :string, default: ""
  attr :name, :string, default: "username"
  attr :label, :string, default: nil
  attr :placeholder, :string, default: nil

  def identifier_input(assigns) do
    assigns =
      assigns
      |> assign(:email?, Identity.email?())
      |> assign_new(:label, fn -> nil end)

    ~H"""
    <.input
      :if={@email?}
      type="email"
      name={@name}
      value={@value}
      label={@label || gettext("Email address")}
      autocomplete="email"
      required
      placeholder={@placeholder || "you@example.org"}
    />
    <.input
      :if={not @email?}
      name={@name}
      value={@value}
      label={@label || gettext("Username")}
      autocomplete="username"
      required
      pattern={identifier_pattern()}
      title={gettext("Letters, digits and underscores, up to thirty")}
      placeholder={@placeholder || gettext("your_username")}
    />
    """
  end

  @doc "Renders the project name with its brand-coloured dot, for the auth and member layouts."
  def wordmark(assigns) do
    ~H"""
    __MODULE__<span
      aria-hidden="true"
      class="ml-[0.12em] inline-block size-[0.28em] rounded-full bg-signal align-baseline ring-[0.1em] ring-signal/25"
    ></span>
    """
  end

  @doc "A compact, shared layout for authentication and first-account setup."
  attr :flash, :map, default: %{}
  attr :title, :string, default: nil
  attr :subtitle, :string, default: nil
  slot :inner_block, required: true

  def auth(assigns) do
    ~H"""
    <main id="auth-main" class="flex min-h-svh items-center justify-center px-6 py-20">
      <div class="w-full max-w-sm">
        <p id="project-name" class="mb-10 text-center text-4xl font-semibold tracking-tight break-words"><.wordmark /></p>
        <div :if={@title} class="mb-8 text-center">
          <h1 class="text-title font-semibold">{@title}</h1>
          <p :if={@subtitle} class="mt-2 text-muted">{@subtitle}</p>
        </div>
        {render_slot(@inner_block)}
      </div>
    </main>
    <.flash_group flash={@flash} />
    """
  end

  @doc "The primary action on an authentication screen."
  attr :rest, :global, include: ~w(type disabled name value)
  slot :inner_block, required: true

  def auth_button(assigns) do
    ~H"""
    <button class="inline-flex min-h-11 w-full cursor-pointer items-center justify-center gap-2 rounded-control bg-accent px-3 py-2 text-sm font-semibold text-on-accent shadow-xs transition-colors hover:bg-accent/85 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent disabled:cursor-not-allowed disabled:opacity-50" {@rest}>
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc "The signed-in application shell."
  attr :flash, :map, required: true
  attr :current_account, :map, required: true
  slot :inner_block, required: true

  def member(assigns) do
    ~H"""
    <div class="min-h-svh">
      <header class="border-b border-line bg-surface">
        <div class="flex items-center justify-between gap-4 px-6 py-5">
          <.link navigate={~p"/"} class="min-w-0 truncate text-xl font-semibold tracking-tight"><.wordmark /></.link>
          <details id="user-menu" class="group relative shrink-0" phx-click-away={JS.remove_attribute("open", to: "#user-menu")} phx-window-keydown={JS.remove_attribute("open", to: "#user-menu")} phx-key="Escape">
            <summary class="flex cursor-pointer list-none items-center gap-2 rounded-control px-3 py-2 text-sm font-semibold hover:bg-selection focus-visible:outline-2 focus-visible:outline-accent">
              <span class="max-w-32 truncate" title={@current_account.username}>{@current_account.username}</span><Lucideicons.chevron_down aria-hidden="true" class="size-4 shrink-0 transition" />
            </summary>
            <nav aria-label={gettext("Your account")} class="absolute right-0 z-20 mt-2 w-56 rounded-xl border border-line bg-surface p-2 shadow-lg">
              <.link navigate={~p"/account/passkeys"} class="block rounded-control px-3 py-2 text-sm hover:bg-selection">{gettext("Manage passkeys")}</.link>
              <.link navigate={~p"/account/recovery-codes"} class="block rounded-control px-3 py-2 text-sm hover:bg-selection">{gettext("Recovery codes")}</.link>
              <.link href={~p"/session"} method="delete" class="mt-1 block rounded-control border-t border-line px-3 py-2 text-sm text-danger hover:bg-danger-surface">{gettext("Sign out")}</.link>
            </nav>
          </details>
        </div>
      </header>
      <main class="mx-auto max-w-3xl px-6 py-12 sm:py-20">{render_slot(@inner_block)}</main>
      <.flash_group flash={@flash} />
    </div>
    """
  end

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://phoenix.hexdocs.pm/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="flex flex-wrap items-center justify-between gap-4 border-b border-line px-4 py-4 sm:px-6 lg:px-8">
      <div class="flex-1">
        <a href="/" class="flex-1 flex w-fit items-center gap-2">
          <img src={~p"/images/logo.svg"} width="36" alt="Phoenix" />
          <span class="text-sm font-semibold">v{Application.spec(:phoenix, :vsn)}</span>
        </a>
      </div>
      <div class="flex-none">
        <ul class="flex flex-wrap items-center gap-3 px-1">
          <li>
            <a href="https://phoenixframework.org/" class="rounded-control px-3 py-2 text-sm font-medium hover:bg-selection focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent">Website</a>
          </li>
          <li>
            <a href="https://github.com/phoenixframework/phoenix" class="rounded-control px-3 py-2 text-sm font-medium hover:bg-selection focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent">GitHub</a>
          </li>
          <li>
            <.button href="https://phoenix.hexdocs.pm/overview.html" variant="primary">
              Get Started <span aria-hidden="true">&rarr;</span>
            </.button>
          </li>
        </ul>
      </div>
    </header>

    <main class="px-4 py-20 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-2xl space-y-4">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <Lucideicons.loader_circle aria-hidden="true" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <Lucideicons.loader_circle aria-hidden="true" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

end
