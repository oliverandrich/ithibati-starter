defmodule __MODULE__.InitialSetup do
  @moduledoc """
  Prints a code issued by Ithibati to the operator's terminal on explicit request.
  """

  alias Ithibati.Identity.Instance
  alias __MODULE__.Claim

  @doc "Print a new code to the operator's terminal from `mise run setup-code` or `bin/setup-code`."
  def print_code! do
    # Asked here as well as at startup, because a release runs this through `eval`. An instance
    # configured wrongly would otherwise meet the library's own refusal, which names a library
    # being used wrongly rather than the key to change.
    Claim.verify!()
    {:ok, _started} = Application.ensure_all_started(:__APP__)

    case Instance.issue_code() do
      {:ok, code} ->
        IO.puts("Initial setup code: #{code}")

      {:error, :already_claimed} ->
        raise "the first account has already claimed this instance"
    end
  end
end
