defmodule __MODULE__.Accounts do
  @moduledoc """
  The administrator role and what it allows: listing accounts, granting and revoking the role,
  and removing an account. The last administrator keeps the role.

  The functions for an administrator take the acting account first and read its flag from the
  database. A stale struct therefore grants nothing. Functions that change data run through
  `with_admin/2`.
  """
  import Ecto.Query

  alias Ithibati.Identity.Sessions
  alias Ithibati.Schema.Identifier
  alias __MODULE__.Accounts.Invitation
  alias __MODULE__.Accounts.User
  alias __MODULE__.Repo

  @doc """
  Lists every account by username for an administrator.

  Returns `{:error, :forbidden}` unless `admin` is one.
  """
  def list_accounts(%User{id: id}) do
    # One read, so the role and the list come from the same snapshot.
    accounts = Repo.all(from u in User, order_by: u.username)

    if Enum.any?(accounts, &(&1.id == id and &1.admin)),
      do: {:ok, accounts},
      else: {:error, :forbidden}
  end

  @doc """
  Makes the account with `account_id` an administrator.

  Returns `{:error, :forbidden}` unless `admin` is one, and `{:error, :not_found}` for an
  unknown account.
  """
  def grant_admin(admin, account_id) do
    admin
    |> with_admin(fn _admins -> account_id |> account() |> set_admin(true) end)
    |> announced()
  end

  @doc """
  Takes the role from the account with `account_id`. An administrator may revoke their own.

  Returns `{:error, :last_admin}` when no other administrator would remain, besides the errors
  of `grant_admin/2`.
  """
  def revoke_admin(admin, account_id) do
    admin
    |> with_admin(fn admins ->
      case account(account_id) do
        %User{id: id} when admins == [id] -> {:error, :last_admin}
        account -> set_admin(account, false)
      end
    end)
    |> announced()
  end

  @doc """
  Subscribes the calling process to role changes of `account`.

  The process receives `:role_changed` after `grant_admin/2` or `revoke_admin/2` returns for
  that account. The message carries no role: broadcasts from two processes arrive in any order,
  so the subscriber reads `admin?/1`.
  """
  def subscribe_role(%User{id: id}), do: Phoenix.PubSub.subscribe(__MODULE__.PubSub, role_topic(id))

  @doc "Whether `account` is an administrator, by the stored role. A removed account is not."
  def admin?(%User{id: id}), do: Repo.exists?(from u in User, where: u.id == ^id and u.admin)

  # After `with_admin/2` returns, so a subscriber reads the committed role. Inside a caller's own
  # transaction, the message can arrive before that transaction commits.
  defp announced({:ok, %User{id: id}} = result) do
    Phoenix.PubSub.broadcast(__MODULE__.PubSub, role_topic(id), :role_changed)
    result
  end

  defp announced(error), do: error

  defp role_topic(id), do: "account_role:#{id}"

  @doc """
  Removes the account with `account_id` with its sessions and open invitations, for an
  administrator.

  Returns `{:ok, %{account: account, digests: digests}}`. Pass the digests to
  `Ithibati.Web.Gate.disconnect_sessions/2` after the commit; do other work outside the database
  there as well. An administrator cannot remove their own account here: `{:error, :self}`.
  Otherwise it returns the errors of `grant_admin/2`.
  """
  def remove_account(%User{id: id} = admin, account_id) do
    with_admin(admin, fn _admins ->
      case account(account_id) do
        nil -> {:error, :not_found}
        %User{id: ^id} -> {:error, :self}
        account -> removed(account)
      end
    end)
  end

  # Data an account owns references `users` with `on_delete: :delete_all`. Cleanup the database
  # cannot do, and that must roll back with the deletion, belongs here.
  defp removed(account) do
    # The inviter column has no foreign key. An open invitation would let somebody in on behalf
    # of an account that is gone.
    Repo.delete_all(from i in Invitation, where: i.invited_by_id == ^account.id and is_nil(i.accepted_at))
    digests = Sessions.revoke_all(account)
    with {:ok, account} <- Repo.delete(account), do: {:ok, %{account: account, digests: digests}}
  end

  @doc """
  Makes the account named `identifier` an administrator, for the operator on the host.

  The identifier is a username, or an address in email mode, normalized as Ithibati stores it.
  It checks no acting account: running a release command already takes access to the host.
  It broadcasts nothing. The release command runs in its own VM, so open pages show the new role
  after a reload.
  """
  def grant_admin_as_operator(identifier) do
    User
    |> Repo.get_by(username: Identifier.normalize(identifier))
    |> set_admin(true)
  end

  @doc """
  Runs `fun` for an administrator, in a transaction that has locked every administrator row.

  `fun` receives the administrators' ids and returns `{:ok, result}` or `{:error, reason}`. An
  error rolls the transaction back. Returns `{:error, :forbidden}` without calling `fun` unless
  `admin` is one. One statement locks the rows in id order, so concurrent changes queue instead
  of deadlocking.
  """
  def with_admin(%User{id: id}, fun) do
    Repo.transaction(fn ->
      admins =
        from(u in User, where: u.admin, select: u.id, order_by: u.id)
        |> Repo.for_update()
        |> Repo.all()

      result = if id in admins, do: fun.(admins), else: {:error, :forbidden}
      committed(result)
    end)
  end

  defp committed({:ok, result}), do: result
  defp committed({:error, reason}), do: Repo.rollback(reason)

  defp account(account_id) do
    case Repo.cast_id(User, account_id) do
      {:ok, id} -> Repo.get(User, id)
      :error -> nil
    end
  end

  defp set_admin(nil, _admin), do: {:error, :not_found}

  defp set_admin(account, admin),
    do: account |> Ecto.Changeset.change(admin: admin) |> Repo.update()
end
