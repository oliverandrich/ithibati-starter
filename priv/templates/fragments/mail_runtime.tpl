
# SMTP submission uses STARTTLS and verifies the server certificate.
if config_env() == :prod do
  smtp_host = System.fetch_env!("SMTP_HOST")
  config :__APP__, :mail_from, {"__MODULE__", System.fetch_env!("MAIL_FROM")}
  config :__APP__, __MODULE__.Mailer,
    adapter: Swoosh.Adapters.SMTP,
    relay: smtp_host,
    port: String.to_integer(System.get_env("SMTP_PORT", "587")),
    username: System.fetch_env!("SMTP_USERNAME"),
    password: System.fetch_env!("SMTP_PASSWORD"),
    auth: :always,
    tls: :always,
    ssl: false,
    retries: 0,
    tls_options: [
      verify: :verify_peer,
      cacerts: :public_key.cacerts_get(),
      server_name_indication: String.to_charlist(smtp_host),
      depth: 99,
      customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]
    ]
end
