defmodule __MODULE__.InvitationEmail do
  @moduledoc "Application-owned invitation content and delivery callbacks for Ithibati."
  use Gettext, backend: __MODULE__Web.Gettext
  import Swoosh.Email

  alias __MODULE__.Mailer

  def content(url, %{username: username}) do
    subject = gettext("Your invitation to %{site}", site: "__MODULE__")
    intro = gettext("Create your passkey to join %{site}.", site: "__MODULE__")
    account = gettext("Username: %{username}", username: username)
    text = "#{intro}\n\n#{account}\n\n#{url}"
    html = "<p>#{escape(intro)}</p><p>#{escape(account)}</p><p><a href=\"#{escape(url)}\">#{escape(url)}</a></p>"
    {:ok, %{subject: subject, text: text, html: html}}
  end

  defp escape(value), do: value |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()

  def deliver(recipient, content) do
    new()
    |> to(recipient)
    |> from(Application.fetch_env!(:__APP__, :mail_from))
    |> subject(content.subject)
    |> text_body(content.text)
    |> html_body(content.html)
    |> Mailer.deliver()
  end
end
