defmodule IthibatiStarter.License do
  @moduledoc false
  alias Igniter.Project.Config
  alias IthibatiStarter.Files

  @spdx %{"mit" => "MIT", "agpl" => "AGPL-3.0-or-later"}

  @doc "Returns the reason the license options are refused, or nil."
  def issue(license, source_url) do
    cond do
      not Map.has_key?(@spdx, license) ->
        "Unknown license #{inspect(license)}; use mit or agpl."

      license == "agpl" and source_url == nil ->
        "AGPL needs --source-url, the address where users get this application's source code."

      license == "agpl" and not absolute_http?(source_url) ->
        "--source-url must be an absolute http or https URL: #{inspect(source_url)}."

      license != "agpl" and source_url != nil ->
        "--source-url applies only with --license agpl."

      true ->
        nil
    end
  end

  def install(igniter, b, opts) do
    license = Keyword.fetch!(opts, :license)
    holder = Keyword.fetch!(opts, :copyright)
    year = Date.utc_today().year

    license_text =
      "licenses/#{license}"
      |> Files.template(b)
      |> String.replace("__YEAR__", to_string(year))
      |> String.replace("__HOLDER__", holder)

    igniter
    |> Igniter.create_new_file("LICENSE", license_text)
    |> Files.append("README.md", """

    ## License

    Copyright (c) #{year} #{holder}

    This application is licensed under `#{@spdx[license]}`. See [LICENSE](LICENSE) for the full text.
    """)
    |> source_url(b, license, opts[:source_url])
  end

  # AGPL section 13: the application offers its source to the users it serves over a network.
  defp source_url(igniter, b, "agpl", url),
    do: Config.configure(igniter, "config.exs", String.to_atom(b.app), [:source_url], url)

  defp source_url(igniter, _b, _license, _url), do: igniter

  defp absolute_http?(url) do
    match?(
      %URI{scheme: scheme, host: host} when scheme in ~w(http https) and host not in [nil, ""],
      URI.parse(url)
    )
  end
end
