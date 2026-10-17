defmodule __MODULE__.Accounts.InvitationTest do
  use __MODULE__.DataCase, async: true

  alias __MODULE__.Accounts.Invitation

  # An open invitation names nobody. Without a note, the list of pending invitations shows a row
  # nobody can tell apart.
  test "an open invitation needs a note, an addressed one does not" do
    open = Invitation.changeset(%Invitation{}, %{"note" => " "}, addressed: false)
    addressed = Invitation.changeset(%Invitation{}, %{"username" => "grace"})

    assert %{note: ["can't be blank"]} = errors_on(open)
    assert addressed.valid?
  end
end
