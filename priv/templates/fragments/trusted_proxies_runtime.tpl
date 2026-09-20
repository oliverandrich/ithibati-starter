
# Which addresses may speak for somebody else. Behind a reverse proxy every request arrives from
# the same socket, so the address a budget is counted against comes from the proxy's header, and
# that header is only believed on a connection from here. The loopback is trusted already, which
# is where a proxy on the same host speaks from. See docs/operations.md.
case "TRUSTED_PROXIES" |> System.get_env("") |> String.trim() do
  "" ->
    :ok

  names ->
    config :__APP__,
           :trusted_proxies,
           names
           |> String.split(",", trim: true)
           |> Enum.map(fn name ->
             name = String.trim(name)

             case :inet.parse_strict_address(to_charlist(name)) do
               {:ok, address} ->
                 address

               {:error, _reason} ->
                 raise """
                 environment variable TRUSTED_PROXIES names something that is not an address: #{inspect(name)}
                 For example: TRUSTED_PROXIES=10.0.0.2,fd00::2
                 """
             end
           end)
end
