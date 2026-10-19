defmodule __MODULE__.Invitations do
  @moduledoc """
  What is outstanding, who made it, and taking one back.

  Before a link is redeemed is the moment to influence who joins; an administrator can remove an
  account afterwards. A page that only makes links leaves that moment invisible.
  Every member may invite and take back their own invitations. An administrator takes back any.
  That rule belongs to this application, not to the library.

  The table is this application's and the invariants are Ithibati's, so the queries come from
  there. `pending_query/0` hands over the predicate `fetch/1` uses, and `withdraw/1` rechecks the
  acceptance inside its delete, so a withdrawal cannot remove an invitation that is being
  redeemed at that moment. Writing either here would be a second opinion about when an invitation
  is still good, and the two would drift.
  """
  import Ecto.Query

  alias Ecto.Changeset
  alias Ithibati.Identity.Invitations
  alias __MODULE__.Accounts.Invitation
  alias __MODULE__.Accounts.User
  alias __MODULE__.Identity
  alias __MODULE__.Repo

  @doc """
  Writes an invitation and records who made it.

  The inviter is put on the changeset rather than cast from the attributes. Who is inviting is
  known to the caller and to nobody else, least of all to the form, and this page hands its
  parameters straight through.

  The plaintext token is on the returned struct and nowhere else: the row holds its digest, and
  anything read back later has an empty one.

  Addressed, the invitation binds the address it is sent to. Named, it is open: the invitee
  chooses the username.

  The inviter's row is locked first, so a removal of that account waits or has already happened.
  An account that is gone opens nothing: `{:error, :not_found}`.
  """
  def open(%User{id: id}, attrs) do
    Repo.transaction(fn ->
      with %User{} <- User |> where(id: ^id) |> Repo.for_update() |> Repo.one(),
           {:ok, invitation} <- insert(id, attrs) do
        invitation
      else
        nil -> Repo.rollback(:not_found)
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  defp insert(inviter_id, attrs) do
    %Invitation{}
    |> Invitation.changeset(attrs, addressed: Identity.email?())
    |> Changeset.put_change(:invited_by_id, inviter_id)
    |> Repo.insert()
  end

  @doc """
  Every invitation that is neither accepted nor run out, soonest to expire first.

  Ordered by expiry rather than by when it was made: the list is read to decide about what is
  about to happen, and the one closest to being used is the one worth seeing first.

  The inviter comes with it. It is `nil` for a row that predates the column, which a table built
  by this project's own migration never has — but an application that turned invitations on
  before schema version 4 will, and the page says so rather than inventing a name.
  """
  def pending do
    Invitations.pending_query()
    |> order_by([i], asc: i.expires_at)
    |> preload(:invited_by)
    |> Repo.all()
  end

  @doc "One invitation by an id from a form, or `nil` for an id that names none."
  def get(id) do
    case Repo.cast_id(Invitation, id) do
      {:ok, id} -> Repo.get(Invitation, id)
      :error -> nil
    end
  end

  @doc """
  Takes back an invitation that has not been accepted, for its inviter or an administrator. Its
  link stops working at once.

  The role is read from the database. Answers `{:error, :forbidden}` for another member and
  `{:error, :already_accepted}` for one that was redeemed in the meantime. Nothing here changes
  an acceptance or an expiry.
  """
  def withdraw(%User{id: id}, %Invitation{invited_by_id: id} = invitation),
    do: Invitations.withdraw(invitation)

  def withdraw(%User{id: id}, invitation) do
    if Repo.exists?(from u in User, where: u.id == ^id and u.admin),
      do: Invitations.withdraw(invitation),
      else: {:error, :forbidden}
  end

  @doc """
  Whether `account` may take back anybody's invitation, by the struct's role.
  The page reads it to word its help. `withdraw/2` decides by the stored role.
  """
  def withdraws_any?(%User{admin: admin}), do: admin

  @doc """
  Whether `account` may take `invitation` back, by the struct's role, to show the button.
  `withdraw/2` decides by the stored role.
  """
  def withdrawable?(%User{id: id} = account, %Invitation{invited_by_id: inviter}),
    do: withdraws_any?(account) or inviter == id
end
