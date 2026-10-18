# The address of this deployment's source code, linked from every layout. An AGPL application
# must offer it, and a deployment of modified code names its own. A wrong address is refused
# here rather than shown as a link that goes nowhere. See docs/operations.md.
case "SOURCE_URL" |> System.get_env("") |> String.trim() do
  "" ->
    :ok

  source_url ->
    case URI.parse(source_url) do
      %URI{scheme: scheme, host: host}
      when scheme in ~w(http https) and is_binary(host) and host != "" ->
        config :__APP__, :source_url, source_url

      _ ->
        raise """
        environment variable SOURCE_URL is not an absolute http or https URL: #{source_url}
        For example: SOURCE_URL=https://example.com/you/__APP__
        """
    end
end
