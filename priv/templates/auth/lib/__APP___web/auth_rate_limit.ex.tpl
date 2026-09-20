defmodule __MODULE__Web.AuthRateLimit do
  @moduledoc """
  Limits auth requests per visitor address, as `__MODULE__Web.ClientIp` resolved it.

  That address comes from the forwarding header when a trusted proxy carried the request, and
  from the socket otherwise. Counting the socket behind a proxy would give everybody one budget.
  `ClientIp.bucket/1` says what counts as one visitor, which for IPv6 is the allocation.
  """
  @behaviour Plug
  import Plug.Conn
  alias __MODULE__.AuthRateLimiter
  alias __MODULE__Web.ClientIp

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    group = if conn.request_path == "/auth/recovery", do: :recovery, else: :ceremony
    {limit, seconds} = AuthRateLimiter.limit(group)
    case AuthRateLimiter.check(key(conn, group), limit, seconds) do
      :ok -> conn
      {:error, retry_after} ->
        conn |> put_resp_header("retry-after", Integer.to_string(retry_after)) |> put_resp_header("cache-control", "no-store") |> put_status(429) |> Phoenix.Controller.json(%{error: "rate_limited"}) |> halt()
    end
  end

  @doc "The budget a request is counted against: one group, one visitor."
  def key(conn, group), do: {group, ClientIp.bucket(conn.remote_ip)}
end
