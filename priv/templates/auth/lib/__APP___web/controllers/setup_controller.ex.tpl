defmodule __MODULE__Web.SetupController do
  @moduledoc "Exchanges the operator's one-time code for a short-lived setup session."
  use __MODULE__Web, :controller

  alias Ithibati.Identity.Instance
  alias __MODULE__.AuthRateLimiter
  alias __MODULE__.InitialSetup

  def authorize(conn, params) do
    conn = put_resp_header(conn, "cache-control", "no-store")

    if Instance.needs_setup?() do
      {limit, seconds} = AuthRateLimiter.limit(:setup)

      case AuthRateLimiter.check({:setup, conn.remote_ip, InitialSetup.current_digest()}, limit, seconds) do
        :ok -> authorize_code(conn, params["setup_code"])

        {:error, retry_after} ->
          conn
          |> put_resp_header("retry-after", Integer.to_string(retry_after))
          |> put_flash(:error, gettext("Too many attempts. Please wait a minute and try again."))
          |> redirect(to: ~p"/setup")
      end
    else
      redirect(conn, to: ~p"/login")
    end
  end

  defp authorize_code(conn, code) do
    case InitialSetup.authorize(code) do
      {:ok, authorization} ->
        conn
        |> put_session(:initial_setup_authorization, authorization)
        |> redirect(to: ~p"/setup")

      {:error, :invalid_setup_code} ->
        conn
        |> put_flash(:error, gettext("That setup code is invalid or has been replaced."))
        |> redirect(to: ~p"/setup")
    end
  end
end
