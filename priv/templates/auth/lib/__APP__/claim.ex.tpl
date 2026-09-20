defmodule __MODULE__.Claim do
  @moduledoc """
  __MODULE__ claims its first account with an operator's code, and supports nothing else.

  Ithibati also offers `initial_claim: :open`, which suits an instance nobody can reach
  before its owner does. This one answers on the network from the moment it starts, so an
  open claim is a race against whoever finds the host first.

  The library option therefore has one permitted value here. `verify!/0` is asked where an
  instance starts, so a wrong value is a refusal to boot rather than a setup page offering
  a field nobody can satisfy.
  """

  alias Ithibati.Config

  @supported :operator_code

  @doc "Answers `:ok`, or raises naming the key to change and the value it takes."
  def verify! do
    case Config.initial_claim_mode() do
      @supported ->
        :ok

      other ->
        raise """
        __MODULE__ claims its first account with an operator's code and supports nothing else.

        config :ithibati, initial_claim: #{inspect(other)}

        Set it to #{inspect(@supported)}, then issue a code: bin/setup-code in an
        unpacked release, mise run setup-code in development.
        """
    end
  end
end
