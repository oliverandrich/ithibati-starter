defmodule __MODULE__Web.ProdConfigTest do
  @moduledoc """
  Production redirects HTTP to HTTPS. Plug then marks the session cookie `Secure`.
  """
  use ExUnit.Case, async: true

  test "production forces HTTPS with HSTS, behind a TLS-terminating proxy as well" do
    force_ssl =
      "config/prod.exs"
      |> Config.Reader.read!(env: :prod)
      |> get_in([:__APP__, __MODULE__Web.Endpoint, :force_ssl])

    assert is_list(force_ssl), "config/prod.exs must set force_ssl"
    # Plug.SSL sends HSTS unless `hsts: false` turns it off.
    assert Keyword.get(force_ssl, :hsts, true)
    assert force_ssl[:rewrite_on] == [:x_forwarded_proto]
    # docs/operations.md names these as the hosts that are not redirected.
    assert force_ssl[:exclude][:hosts] == ["localhost", "127.0.0.1"]
  end
end
