defmodule __MODULE__Web.SetupController do
  @moduledoc "Exchanges the operator's one-time code for a short-lived setup session."
  use __MODULE__Web, :controller

  alias Ithibati.Identity.Instance
  alias __MODULE__.AuthRateLimiter
  alias __MODULE__Web.AuthRateLimit

  def authorize(conn, params) do
    conn = put_resp_header(conn, "cache-control", "no-store")

    if Instance.needs_setup?() do
      {limit, seconds} = AuthRateLimiter.budget(:setup)

      case AuthRateLimiter.check(AuthRateLimit.key(conn, :setup), limit, seconds) do
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
    case Instance.authorize_code(code) do
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
