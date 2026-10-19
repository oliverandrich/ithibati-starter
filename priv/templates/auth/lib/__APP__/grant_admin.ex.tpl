defmodule __MODULE__.GrantAdmin do
  @moduledoc """
  Makes an account an administrator from `bin/grant-admin`, on the host.

  The operator's way back when an instance has no administrator, for example because its first
  account was deleted.
  """
  alias Ithibati.Schema.Identifier
  alias __MODULE__.Accounts
  alias __MODULE__.Claim

  @doc """
  Makes the account named `identifier` an administrator and says so. In email mode the
  identifier is the account's address. Returns `{:error, :not_found}` for an unknown one.
  """
  def run(identifier) do
    case Accounts.grant_admin_as_operator(identifier) do
      {:ok, account} ->
        IO.puts("#{account.username} is an administrator.")
        :ok

      {:error, :not_found} = error ->
        IO.puts("No account is named #{Identifier.normalize(identifier)}. Nothing changed.")
        error
    end
  end

  @doc "Runs `run/1` for `GRANT_ADMIN_IDENTIFIER` and halts with status 1 on error."
  def run! do
    # A release runs this through `eval`, which skips the check at startup.
    Claim.verify!()
    {:ok, _started} = Application.ensure_all_started(:__APP__)

    # A shell script reads the exit status, not the returned term.
    case run(System.fetch_env!("GRANT_ADMIN_IDENTIFIER")) do
      :ok -> :ok
      _error -> System.halt(1)
    end
  end
end
