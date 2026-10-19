defmodule __MODULE__Web.PlaywrightCase do
  @moduledoc """
  Case template for browser features in Playwright's Chrome for Testing.

  A passkey ceremony needs `navigator.credentials`, a `fetch` that sets a cookie, and a redirect
  the hook follows. `Phoenix.LiveViewTest` has none of these, so these features drive a browser.
  They also execute `priv/static/ithibati.js`, the client half of Ithibati.

  Each feature gets a new browser context in a pooled browser, so nothing carries over.
  The sandbox runs in shared mode, so a test can read in the database what the browser stored.
  Per feature, `@tag browser_context_opts: [...]` sets the locale, viewport or colour scheme.
  """
  use ExUnit.CaseTemplate

  import PhoenixTest

  alias Ithibati.Identity.Instance
  alias PlaywrightEx.Connection
  alias PlaywrightEx.Frame

  using do
    quote do
      use PhoenixTest.Playwright.Case

      # The PostgreSQL pass excludes `:feature`.
      @moduletag :feature

      setup do
        __MODULE__.SetupSupport.forget_rate_limits()
        :ok
      end

      setup %{conn: conn}, do: __MODULE__Web.PlaywrightCase.fail_on_page_errors(conn)
      setup %{conn: conn}, do: __MODULE__Web.PlaywrightCase.leave_page_at_exit(conn)

      import __MODULE__Web.PlaywrightCase
      import Ithibati.Testing.Passkeys

      alias __MODULE__.Accounts.User
      alias __MODULE__.Repo
    end
  end

  @doc """
  Fails the feature after it ends if the page had an uncaught error.

  Playwright reports these errors as events of the browser context, which no assertion sees.
  The collector is not linked, because `on_exit` runs after the test process has exited.
  The check runs before the browser context closes, because `on_exit` callbacks run in reverse order.
  """
  def fail_on_page_errors(%{context_id: context}) do
    collector = spawn(fn -> collect_page_errors([]) end)
    :ok = Connection.subscribe(connection(), collector, context)

    on_exit(fn ->
      send(collector, {:page_errors, self()})

      receive do
        {:page_errors, []} -> :ok
        {:page_errors, errors} -> flunk("the page threw:\n\n" <> Enum.join(errors, "\n\n"))
      after
        timeout() ->
          Process.exit(collector, :kill)
          flunk("the page error collector did not answer")
      end
    end)
  end

  @doc """
  Navigates the page to `about:blank` when the feature ends, before the sandbox owner stops.

  Leaving ends the page's LiveViews, so none queries the database after its sandbox is gone.
  It waits for the page, where `ecto_sandbox_stop_owner_delay` would wait a fixed time.
  This `on_exit` runs before the case's own, because `on_exit` callbacks run in reverse order.
  """
  def leave_page_at_exit(%{frame_id: frame}) do
    on_exit(fn -> Frame.goto(frame, url: "about:blank", timeout: timeout()) end)
  end

  defp collect_page_errors(errors) do
    receive do
      {:playwright_msg, %{method: :page_error, params: params}} ->
        collect_page_errors([page_error_message(params) | errors])

      {:page_errors, pid} ->
        send(pid, {:page_errors, Enum.reverse(errors)})

      _other ->
        collect_page_errors(errors)
    end
  end

  defp page_error_message(%{error: %{error: %{message: message}}}), do: message
  defp page_error_message(params), do: inspect(params)

  @doc """
  Visits `path` and waits until its LiveView is connected.

  The page answers before its socket joins. Until then `phx-submit` is not bound, so a click goes
  nowhere. Measured: without the wait about one suite run in three failed.
  """
  def open(conn, path), do: conn |> visit(path) |> connected()

  @doc "Waits until the current page's LiveView is connected, for a page reached by a click."
  def connected(conn), do: assert_has(conn, "[data-phx-main].phx-connected")

  @doc "Issues the operator code and enters it in the real setup form."
  def unlock_setup(conn) do
    {:ok, code} = Instance.issue_code()

    conn
    |> open("/setup")
    |> fill("input[name=setup_code]", code)
    |> PhoenixTest.Playwright.click("#setup-code-form button")
    |> assert_has("#claim-form")
    |> connected()
  end

  @doc "Scrolls the page's large heading under the top bar, which then shows the title."
  def scroll_past_heading(conn) do
    conn
    |> PhoenixTest.Playwright.evaluate("""
    document.querySelector('#main-content').insertAdjacentHTML('beforeend', '<div style="height: 3000px"></div>')
    window.scrollTo(0, 1500)
    """)
    |> assert_has("#app-header[data-shrunk]")
  end

  @doc """
  Calls the JavaScript function `function` in the page and returns its result.

  The function may return a Promise. The test receives what it resolves to.
  """
  def value_of(%{frame_id: frame}, function) do
    opts = [expression: function, is_function: true, timeout: timeout()]

    case Frame.evaluate(frame, opts) do
      {:ok, value} -> value
      {:error, error} -> flunk("the script failed: #{inspect(error)}\n\n#{function}")
    end
  end

  @doc """
  Fills the field `selector` matches with `value`, replacing what it held.

  For fields a test reaches by name rather than by label, such as on a page in another language.
  """
  def fill(%{frame_id: frame} = conn, selector, value) do
    {:ok, _} = Frame.fill(frame, selector: selector, value: value, timeout: timeout())
    conn
  end

  @doc "Sets the page's viewport in CSS pixels."
  def resize(conn, width, height),
    do: page_call(conn, "setViewportSize", %{viewportSize: %{width: width, height: height}})

  @doc ~s|Emulates the system colour scheme, `"light"` or `"dark"`, for `prefers-color-scheme`.|
  def color_scheme(conn, scheme), do: page_call(conn, "emulateMedia", %{colorScheme: scheme})

  # playwright_ex has no wrapper for these page methods, so they are sent by protocol name.
  defp page_call(%{page_id: page} = conn, method, params) do
    case Connection.send(connection(), %{guid: page, method: method, params: params}, timeout()) do
      %{error: error} -> raise "#{method} failed: #{inspect(error)}"
      _reply -> conn
    end
  end

  @doc """
  Returns context options for a phone of `width` by `height` CSS pixels.
  For `@tag browser_context_opts: phone(390, 844)`.
  """
  def phone(width, height) do
    [
      viewport: %{width: width, height: height},
      device_scale_factor: 1.0,
      is_mobile: true,
      has_touch: true
    ]
  end

  defp connection, do: PlaywrightEx.Supervisor.connection_name()
  # Read once at compile time, so a call does not validate the whole Playwright config again.
  @timeout Application.compile_env(:phoenix_test, [:playwright, :timeout], 2_000)
  defp timeout, do: @timeout
end
