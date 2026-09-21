defmodule __MODULE__.ClaimTest do
  @moduledoc """
  The one claim mode this application supports, asked where an instance starts.

  Ithibati's `:open` mode reads like less restriction and is a dead end here: no code can be
  issued and no proof is ever accepted. An instance configured that way must say so and stop
  rather than serve a setup page that offers a field nobody can satisfy.
  """
  # async: false — `initial_claim` is application config, and two of these change it.
  use ExUnit.Case, async: false

  alias __MODULE__.Claim
  alias __MODULE__.SetupSupport

  defp with_claim(mode, fun) do
    SetupSupport.put_env(:ithibati, :initial_claim, mode)
    fun.()
  end

  # The posture this ships with, asked of the configuration every environment actually loads.
  # A posture that only holds in production is a posture nothing runs against.
  test "the mode this application ships with is the one it supports" do
    assert Claim.verify!() == :ok
  end

  test "an open claim is refused, and the message names the key to change" do
    with_claim(:open, fn ->
      assert_raise RuntimeError, ~r/initial_claim/, &Claim.verify!/0
    end)
  end

  # The library refuses a value it cannot read at all, which says the same thing louder.
  test "a mode the library cannot read is refused too" do
    with_claim(:operator_codes, fn ->
      assert_raise ArgumentError, ~r/initial_claim/, &Claim.verify!/0
    end)
  end
end
