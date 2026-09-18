defmodule __MODULE__Web.HealthController do
  @moduledoc "Public liveness probe; intentionally independent of the database and session."
  use __MODULE__Web, :controller

  def show(conn, _params) do
    conn |> put_resp_header("cache-control", "no-store") |> json(%{status: "ok"})
  end
end
