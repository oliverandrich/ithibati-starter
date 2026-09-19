defmodule __MODULE__.Invitations do
  @moduledoc "Creates username invitations, then delivers them outside the transaction."
  alias Ithibati.InvitationMail
  alias Ithibati.Schema.Identifier
  alias __MODULE__.Accounts.Invitation
  alias __MODULE__.InvitationEmail
  alias __MODULE__.Repo
  alias __MODULE__Web.Endpoint

  def send_email(params, deliver \\ &InvitationEmail.deliver/2) do
    with {:ok, recipient} <- recipient(params),
         {:ok, invitation} <- %Invitation{} |> Invitation.changeset(params) |> Repo.insert() do
      # Endpoint configuration is trusted; a request Host header must never control this URL.
      url = Endpoint.url() <> "/invite/" <> invitation.token
      InvitationMail.deliver(recipient, url,
        enabled: true,
        content: &InvitationEmail.content/2,
        deliver: deliver,
        context: %{username: invitation.username}
      )
    end
  end

  def recipient(%{"email" => email}) when is_binary(email) do
    recipient = String.trim(email)
    if byte_size(recipient) <= 254 and Regex.match?(Identifier.email_format(), recipient),
      do: {:ok, recipient}, else: {:error, :invalid_recipient}
  end

  def recipient(_params), do: {:error, :invalid_recipient}
end
