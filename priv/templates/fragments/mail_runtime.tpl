
# Mail is opt-in and an instance that addresses its accounts requires it, which
# `__MODULE__.Identity` checks where the instance starts. Enabling it here means a working SMTP
# submission configuration: a missing value stops the boot rather than failing at the first
# invitation.
mail_enabled? =
  case "MAIL_ENABLED" |> System.get_env("") |> String.trim() do
    "" -> false
    "true" -> true
    "false" -> false
    other -> raise ~s(environment variable MAIL_ENABLED is neither "true" nor "false": #{other})
  end

if config_env() != :test and mail_enabled? do
  smtp_host = System.fetch_env!("SMTP_HOST")
  smtp_port = String.to_integer(System.get_env("SMTP_PORT", "587"))

  config :__APP__, :mail_enabled, true
  config :__APP__, :mail_from, {"__MODULE__", System.fetch_env!("MAIL_FROM")}

  config :__APP__, __MODULE__.Mailer,
    adapter: Swoosh.Adapters.SMTP,
    relay: smtp_host,
    port: smtp_port,
    username: System.fetch_env!("SMTP_USERNAME"),
    password: System.fetch_env!("SMTP_PASSWORD"),
    auth: :always,
    # 465 is implicit TLS and 587 is STARTTLS. Hardcoding either one against a port the operator
    # sets means a client speaking the wrong thing, and finding out at the first invitation.
    tls: if(smtp_port == 465, do: :never, else: :always),
    ssl: smtp_port == 465,
    retries: 0,
    # Delivery happens on the process handling the request, so a relay that accepts the
    # connection and then stalls would hold it for gen_smtp's own default, which is minutes.
    timeout: 15_000,
    tls_options: [
      verify: :verify_peer,
      cacerts: :public_key.cacerts_get(),
      server_name_indication: String.to_charlist(smtp_host),
      depth: 99,
      customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]
    ]
end
