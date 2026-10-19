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

  @doc """
  The address of the application's source code, or nil.

  It is read at render time. `SOURCE_URL` replaces `:source_url` when the application boots.
  """
  def source_url, do: Application.get_env(:__APP__, :source_url)

  @doc """
  Links to the application's source code, which an AGPL application must offer its users.

  Render it inside an element with `:if={source_url()}`, so no empty wrapper takes space.
  """
  attr :class, :any, default: "underline underline-offset-2"

  def source_offer(assigns) do
    assigns = assign(assigns, :url, source_url())

    ~H"""
    <a href={@url} target="_blank" rel="noopener noreferrer" class={@class}>
      {gettext("Source code")}
    </a>
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
        <p :if={source_url()} class="mt-10 text-center text-sm text-muted"><.source_offer /></p>
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

  @doc """
  The signed-in application layout.

  Below `lg` the header is a top bar, and a tab bar links the places once there are two.
  From `lg` the same header is the left column with the sidebar.
  `__MODULE__Web.Navigation` lists the places; `section` marks the page's own.

  `layout={:sidebar}`, the default, renders the inner block in the main column.
  `layout={:columns}` renders only the `:list` and `:detail` slots, side by side from `lg`.
  A phone shows the list, or the detail once `selected` is true.

  `docs/interface.md` says when to use which layout and shape.
  """
  attr :flash, :map, required: true
  attr :current_account, :map, required: true
  attr :section, :atom, default: nil, doc: "the navigation entry the page belongs to"

  attr :navigation, :list,
    default: nil,
    doc: "the places to link; `__MODULE__Web.Navigation.items/1` by default"

  attr :title, :string,
    default: nil,
    doc: "the page's title, which a phone's bar shows once the large heading has scrolled away"

  attr :back, :map,
    default: nil,
    doc: "`%{to: path, label: text}`, where a phone's bar leads back to; `patch:` stays in the view"

  attr :breadcrumb, :boolean,
    default: false,
    doc: "whether wide screens in `:sidebar`, which hide the bar's back link, show a breadcrumb"

  attr :layout, :atom, default: :sidebar, values: [:sidebar, :columns]
  attr :selected, :boolean, default: false, doc: "whether a phone shows the detail in `:columns`"
  slot :inner_block, doc: "the page in `:sidebar`"
  slot :list, doc: "the list pane in `:columns`"
  slot :detail, doc: "the detail pane in `:columns`"

  def member(assigns) do
    places = assigns.navigation || __MODULE__Web.Navigation.items(assigns.current_account)
    assigns = assign(assigns, places: places, tabs?: length(places) > 1)

    ~H"""
    <div class={[
      "min-h-svh lg:grid lg:grid-cols-[256px_minmax(0,1fr)] lg:pb-0",
      @tabs? && "pb-[calc(var(--nav-bar)+var(--safe-bottom))]"
    ]}>
      <%!-- Below `lg` a sticky top bar; see assets/js/shrink_title.js. --%>
      <header
        id="app-header"
        phx-hook="ShrinkTitle"
        phx-mounted={JS.ignore_attributes(["data-shrunk"])}
        class="group sticky top-0 z-30 flex flex-wrap items-center justify-between gap-4 lg:h-svh lg:flex-col lg:flex-nowrap lg:items-stretch lg:justify-start lg:gap-5 lg:overflow-y-auto lg:border-r lg:border-line lg:px-3 lg:py-4"
      >
        <%!-- The translucent background is set here, not on the header. A `backdrop-filter` on
             the header would make it the containing block of the fixed tab bar. --%>
        <div
          id="masthead"
          class="relative flex w-full items-center justify-between gap-3 bg-ground/85 px-4 py-1.5 backdrop-blur-md sm:px-10 lg:bg-transparent lg:py-0 lg:pr-0 lg:pl-2.5 lg:backdrop-blur-none"
        >
          <.link
            :if={@back}
            id="nav-back"
            navigate={@back[:to]}
            patch={@back[:patch]}
            class="flex min-h-11 items-center gap-0.5 text-body font-medium text-accent lg:hidden"
          >
            <Lucideicons.chevron_left aria-hidden="true" class="-ml-1.5 size-6" />
            {@back.label}
          </.link>
          <.link
            navigate={~p"/"}
            class={["min-w-0 items-center", if(@back, do: "hidden lg:flex", else: "flex")]}
          >
            <span class="truncate text-2xl leading-none font-bold tracking-tight lg:text-[26px]"><.wordmark /></span>
          </.link>
          <%!-- Shows the page title once the large heading scrolls out of view. --%>
          <p
            :if={@title}
            id="nav-title"
            aria-hidden="true"
            class="pointer-events-none absolute inset-x-28 truncate text-center text-label font-semibold opacity-0 transition-opacity group-data-[shrunk]:opacity-100 lg:hidden"
          >
            {@title}
          </p>
          <details
            id="user-menu"
            class="relative shrink-0"
            phx-click-away={JS.remove_attribute("open", to: "#user-menu")}
            phx-window-keydown={JS.remove_attribute("open", to: "#user-menu")}
            phx-key="Escape"
          >
            <summary
              aria-label={gettext("Account menu, %{username}", username: @current_account.username)}
              title={@current_account.username}
              class="flex size-11 cursor-pointer list-none items-center justify-center rounded-control text-muted hover:bg-surface hover:text-ink focus-visible:outline-2 focus-visible:outline-accent lg:size-7"
            >
              <Lucideicons.circle_user aria-hidden="true" class="size-5 lg:size-4.5" />
            </summary>
            <nav
              aria-label={gettext("Your account")}
              class="absolute top-full right-0 z-40 mt-2 w-56 rounded-control border border-line bg-surface p-1 text-label shadow-lg"
            >
              <p class="mb-1 truncate border-b border-line px-3 pt-2 pb-2.5 font-semibold">{@current_account.username}</p>
              <.link navigate={~p"/account/passkeys"} class="block rounded-control px-3 py-2 hover:bg-ground">{gettext("Manage passkeys")}</.link>
              <.link navigate={~p"/account/recovery-codes"} class="block rounded-control px-3 py-2 hover:bg-ground">{gettext("Recovery codes")}</.link>
              <.link href={~p"/session"} method="delete" class="mt-1 block rounded-control border-t border-line px-3 py-2 text-danger hover:bg-danger-surface">{gettext("Sign out")}</.link>
            </nav>
          </details>
        </div>
        <nav id="sidebar" aria-label={gettext("Main navigation")} class="hidden flex-col gap-0.5 lg:flex">
          <.link
            :for={place <- @places}
            id={"sidebar-#{place.section}"}
            navigate={place.to}
            aria-current={place.section == @section && "page"}
            class="flex min-h-9 items-center gap-2.5 rounded-control px-2.5 text-label text-muted hover:bg-surface hover:text-ink aria-[current=page]:bg-selection aria-[current=page]:font-semibold aria-[current=page]:text-accent"
          >
            <Lucideicons.render! name={place.icon} aria-hidden="true" class="size-4 shrink-0" />
            <span class="min-w-0 truncate">{place.label}</span>
          </.link>
        </nav>
        <div :if={source_url()} id="colophon" class="hidden text-meta text-muted lg:mt-auto lg:block lg:px-2.5 lg:pb-1">
          <.source_offer />
        </div>
        <%!-- Phone tab bar in iOS style: icon and label per place, above the safe-area inset. --%>
        <nav
          :if={@tabs?}
          id="main-navigation"
          aria-label={gettext("Main navigation")}
          class="fixed inset-x-0 bottom-0 z-30 flex h-[calc(var(--nav-bar)+var(--safe-bottom))] items-stretch justify-around border-t border-line bg-ground/85 pb-[var(--safe-bottom)] backdrop-blur-md lg:hidden"
        >
          <.link
            :for={place <- @places}
            id={"tab-#{place.section}"}
            navigate={place.to}
            aria-current={place.section == @section && "page"}
            class="flex min-w-16 flex-1 flex-col items-center justify-center gap-0.5 text-[10px] font-medium text-muted aria-[current=page]:text-accent"
          >
            <Lucideicons.render! name={place.icon} aria-hidden="true" class="size-6" />
            <span>{place.label}</span>
          </.link>
        </nav>
      </header>
      <div class="min-w-0">
        <main
          :if={@layout == :sidebar}
          id="main-content"
          class="mx-auto max-w-7xl px-6 py-6 sm:px-12 sm:py-12 lg:max-w-none lg:px-10 lg:py-10"
        >
          <nav
            :if={@breadcrumb && @back && @title}
            id="breadcrumb"
            aria-label={gettext("Breadcrumb")}
            class="mb-4 hidden items-center gap-1 text-label text-muted lg:flex"
          >
            <.link navigate={@back[:to]} patch={@back[:patch]} class="hover:text-ink">{@back.label}</.link>
            <Lucideicons.chevron_right aria-hidden="true" class="size-4" />
            <span aria-current="page" class="text-ink">{@title}</span>
          </nav>
          {render_slot(@inner_block)}
        </main>
        <%!-- From lg the page does not scroll; each pane scrolls on its own and takes the keyboard
             through `tabindex`. The list stands beside the detail, so no breadcrumb is needed. --%>
        <main
          :if={@layout == :columns}
          id="main-content"
          class="lg:grid lg:h-svh lg:grid-cols-[28rem_minmax(0,1fr)]"
        >
          <section
            id="list-pane"
            tabindex="0"
            class={[pane_class(), "lg:border-r lg:border-line lg:bg-surface", @selected && "hidden lg:block"]}
          >
            {render_slot(@list)}
          </section>
          <section id="detail-pane" tabindex="0" class={[pane_class(), !@selected && "hidden lg:block"]}>
            {render_slot(@detail)}
          </section>
        </main>
      </div>
      <.flash_group flash={@flash} />
    </div>
    """
  end

  defp pane_class,
    do:
      "min-w-0 focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-accent lg:h-svh lg:overflow-y-auto lg:overscroll-none"

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
    <footer :if={source_url()} class="px-4 pb-10 text-sm text-muted sm:px-6 lg:px-8"><.source_offer /></footer>

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
