defmodule __MODULE__.AuthCleanup do
  @moduledoc "Deletes expired auth records. `__MODULE__.AuthCleanup.Worker` runs it hourly."
  alias Ithibati.Identity.Challenges
  alias Ithibati.Identity.Invitations
  alias Ithibati.Web.Gate

  def run do
    %{
      # Through the endpoint, so the LiveViews of an expired session are disconnected too.
      sessions: Gate.expire(__MODULE__Web.Endpoint),
      challenges: Challenges.delete_expired(),
      invitations: Invitations.delete_expired()
    }
  end
end
