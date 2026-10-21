defmodule __MODULE__.IdentityCheck do
  @moduledoc """
  Refuses to start a release whose stored identifiers contradict the identity mode.

  `ACCOUNT_IDENTITY` is read on every start, but an identifier keeps the format it was written in.
  A username never contains `@` and an address always does, so one query tells the modes apart.

  It runs after `Ecto.Migrator` and is skipped where that is, so only a migrated release is asked.
  """
  import Ecto.Query

  alias __MODULE__.Accounts.User
  alias __MODULE__.Identity
  alias __MODULE__.Repo

  def child_spec(opts),
    do: %{id: __MODULE__.IdentityCheck, start: {__MODULE__.IdentityCheck, :start_link, [opts]}}

  # Nothing is left running, so the supervisor is told to ignore the child.
  def start_link(skip: true), do: :ignore

  def start_link(skip: false) do
    verify!()
    :ignore
  end

  @doc "Answers `:ok`, or raises when an account's identifier is in the other mode's format."
  def verify! do
    mode = Identity.mode()

    contradicting =
      case mode do
        :username -> where(User, [u], like(u.username, "%@%"))
        :email -> where(User, [u], not like(u.username, "%@%"))
      end

    if Repo.exists?(contradicting) do
      raise """
      config :__APP__, account_identity: #{inspect(mode)}

      This instance already has accounts in the other mode. Each instance chooses once, before the
      first account. Set ACCOUNT_IDENTITY back to what it was. See docs/operations.md.
      """
    end

    :ok
  end
end
