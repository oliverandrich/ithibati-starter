defmodule __MODULE__.Mailer do
  @moduledoc "Application mail delivery; local preview in development, SMTP in production."
  use Swoosh.Mailer, otp_app: :__APP__
end
