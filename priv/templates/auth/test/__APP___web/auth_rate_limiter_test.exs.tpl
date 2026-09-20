defmodule __MODULE__Web.AuthRateLimiterTest do
  use ExUnit.Case, async: true
  alias __MODULE__.AuthRateLimiter

  setup do
    server = start_supervised!({AuthRateLimiter, name: __MODULE__Web.AuthRateLimiterTest})
    %{server: server}
  end

  test "concurrent callers share one limit, different keys do not", %{server: server} do
    results = 1..20 |> Task.async_stream(fn _ -> AuthRateLimiter.check(:one, 3, 60, server) end) |> Enum.to_list()
    assert Enum.count(results, &(&1 == {:ok, :ok})) == 3
    assert AuthRateLimiter.check(:two, 3, 60, server) == :ok
  end

  test "manual invitation accounts have separate budgets that reset after the window", %{server: server} do
    first = {:manual_invitation, 1}
    second = {:manual_invitation, 2}

    assert AuthRateLimiter.check(first, 1, 1, server) == :ok
    assert {:error, _seconds} = AuthRateLimiter.check(first, 1, 1, server)
    assert AuthRateLimiter.check(second, 1, 1, server) == :ok

    Process.sleep(1100)
    assert AuthRateLimiter.check(first, 1, 1, server) == :ok
  end
end
