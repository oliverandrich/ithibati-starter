
# An account is named or addressed. Addressing them requires the mail configuration above, and
# `__MODULE__.Identity` refuses to start an instance that asks for one without the other.
#
# Not in tests, where a shell that happens to export this would otherwise decide what the suite
# runs against.
if config_env() != :test do
  case "ACCOUNT_IDENTITY" |> System.get_env("") |> String.trim() do
    "" ->
      :ok

    "username" ->
      config :__APP__, :account_identity, :username

    "email" ->
      config :__APP__, :account_identity, :email

    other ->
      raise """
      environment variable ACCOUNT_IDENTITY is neither: #{inspect(other)}

      An account is named or addressed, so this is "username" or "email".
      """
  end
end
