defmodule __MODULE__.SetupSupport do
  @moduledoc false

  alias Ithibati.Identity.Instance

  def authorize_conn(conn) do
    {:ok, code} = Instance.issue_code()
    {:ok, authorization} = Instance.authorize_code(code)
    Plug.Conn.put_session(conn, :initial_setup_authorization, authorization)
  end

  @doc """
  Empties the shared rate limiter when the tests run on SQLite.

  The sandbox rolls SQLite's id counter back after each test, so the next test's account gets the
  same id. A budget counted against that id would carry over. PostgreSQL never reuses an id, and
  its tests run concurrently, so its limiter is left alone.
  """
  def forget_rate_limits do
    if Application.fetch_env!(:__APP__, :database) == :sqlite,
      do: :sys.replace_state(__MODULE__.AuthRateLimiter, fn _ -> %{} end)

    :ok
  end

  @doc """
  Sets one rate-limit budget for the length of the test, leaving every other group standing.

  `:auth_rate_limits` is one keyword list holding all of them, so writing it whole is how a test
  quietly takes away a budget that somebody else's setup put there, and the group then falls back
  to its shipped default rather than to what was wanted.
  """
  def put_budget(group, budget) do
    configured = Application.get_env(:__APP__, :auth_rate_limits, [])

    put_env(:__APP__, :auth_rate_limits, Keyword.put(configured, group, budget))
  end

  @doc "Names this instance's accounts the given way for the length of the test."
  def put_identity(mode), do: put_env(:__APP__, :account_identity, mode)

  @doc "Removes a key for the length of the test and restores what was there, absence included."
  def delete_env(app, key) do
    remember(app, key)
    Application.delete_env(app, key)
  end

  @doc "Sets a key for the length of the test and restores what was there, absence included."
  def put_env(app, key, value) do
    remember(app, key)
    Application.put_env(app, key, value)
  end

  # Every test module that changes application config has to leave the suite as it found it.
  # Written once so that restoring is not something any of them has to remember.
  defp remember(app, key) do
    previous = Application.fetch_env(app, key)

    ExUnit.Callbacks.on_exit(fn ->
      case previous do
        {:ok, was} -> Application.put_env(app, key, was)
        :error -> Application.delete_env(app, key)
      end
    end)
  end
end
