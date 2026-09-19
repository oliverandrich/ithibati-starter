defmodule __MODULE__Web.InvitationController do
  @moduledoc "Invitation delivery, authenticated afresh and rate limited on each request."
  use __MODULE__Web, :controller

  alias __MODULE__.AuthRateLimiter
  alias __MODULE__.Invitations

  def create(conn, %{"invitation" => params}) when is_map(params) do
    with {:ok, recipient} <- Invitations.recipient(params),
         :ok <- AuthRateLimiter.check({:mail_sender, conn.assigns.current_account.id}, 10, 3600),
         :ok <- AuthRateLimiter.check({:mail_recipient, String.downcase(recipient)}, 3, 3600) do
      result(conn, Invitations.send_email(params))
    else
      {:error, seconds} when is_integer(seconds) ->
        conn |> put_flash(:error, gettext("Too many invitations. Please try again later.")) |> redirect(to: ~p"/")
      {:error, reason} -> result(conn, {:error, reason})
    end
  end

  def create(conn, _params), do: result(conn, {:error, :invalid_recipient})

  defp result(conn, {:ok, _receipt}),
    do: conn |> put_flash(:info, gettext("Invitation email sent.")) |> redirect(to: ~p"/")

  defp result(conn, {:error, :invalid_recipient}),
    do: conn |> put_flash(:error, gettext("Please enter a valid email address.")) |> redirect(to: ~p"/")

  defp result(conn, {:error, %Ecto.Changeset{}}),
    do: conn |> put_flash(:error, gettext("Please check the username and try again.")) |> redirect(to: ~p"/")

  defp result(conn, {:error, _reason}),
    do: conn |> put_flash(:error, gettext("The email could not be sent. Please try again later or share a link manually.")) |> redirect(to: ~p"/")
end
