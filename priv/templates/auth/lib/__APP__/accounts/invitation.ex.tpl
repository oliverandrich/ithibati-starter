defmodule __MODULE__.Accounts.Invitation do
  @moduledoc """
  The invitations table is ours, the same arrangement as the accounts table.

  Ithibati adds the invitee's identifier, the token digest, an expiry and an acceptance timestamp;
  what an invitation *grants* is this application's to add. There is nothing here beyond the
  minimum, because this example is about the flow rather than about roles.
  """
  use Ecto.Schema

  alias Ithibati.Schema.Invitation

  # The same identifier the account schema is keyed by — the configuration refuses the pair when it
  # is not, which is the mistake worth catching at boot rather than at the first invitation. The
  # shape is named the same way it is named there, so the two cannot disagree about it.
  use Invitation,
    identifier: :username,
    format: {__MODULE__.Identity, :format},
    format_message: {__MODULE__.Identity, :format_message}

  schema "invitations" do
    ithibati_invitation()

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  The invitation, or a refusal that cost nothing to arrive at.

  Nothing of its own: `invitation_changeset/3` applies the shape this instance asks for, and
  skips minting a token and asking the accounts table for a value it has already refused. This
  used to unpick that order by hand, because the format could only be a literal.
  """
  def changeset(invitation, attrs, opts \\ []),
    do: invitation_changeset(invitation, attrs, opts)
end
