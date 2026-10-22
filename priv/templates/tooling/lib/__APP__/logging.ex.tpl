defmodule __MODULE__.Logging do
  @moduledoc """
  Production logging: one JSON object per line at `LOG_LEVEL`, on stdout or in `LOG_FILE`.

  Only the metadata named here reaches a line. Messages are not filtered, so callers keep names,
  codes and tokens out of them. See docs/operations.md.
  """

  alias LoggerJSON.Formatters.Basic

  # Phoenix's request id. Add a key here before logging it as metadata.
  @metadata [:request_id]

  # No debug: it enables LiveView and Ecto lines that include sessions and query parameters.
  @levels ~w(emergency alert critical error warning notice info)

  @doc "Returns the production log formatter."
  def formatter, do: Basic.new(metadata: @metadata)

  @doc """
  Returns the handler filters. Supplied filters replace Logger's default, so this list restates
  `remote_gl`, which keeps events from remote shells off the release's stdout.
  """
  def filters do
    [
      remote_gl: {&:logger_filters.remote_gl/2, :stop},
      drop_request: {&__MODULE__.Logging.drop_request/2, nil}
    ]
  end

  @doc """
  Logger filter that removes `:conn` from event metadata, as attached to a crashed request.
  The formatter would log its path, which may hold identifiers or codes, and the client's address
  and user agent.
  """
  def drop_request(%{meta: meta} = event, _config), do: %{event | meta: Map.delete(meta, :conn)}

  @doc """
  Returns the handler's output config for `LOG_FILE`. Without a value the handler writes to
  stdout. A file rotates at 10 MB and keeps five compressed predecessors. Creates its directory.
  Raises `ArgumentError` for a relative path or one that cannot be written.
  """
  def handler_config(value) do
    case value |> to_string() |> String.trim() do
      "" ->
        []

      "/" <> _ = path ->
        writable!(path)

        [
          file: String.to_charlist(path),
          max_no_bytes: 10_000_000,
          max_no_files: 5,
          compress_on_rotate: true
        ]

      _ ->
        raise ArgumentError, "LOG_FILE must be an absolute path, not #{inspect(value)}"
    end
  end

  # Logger only warns on stderr when it cannot open the file, and the release then logs nothing.
  # The path comes from the operator's environment, not from a request.
  # sobelow_skip ["Traversal.FileModule"]
  defp writable!(path) do
    with :ok <- File.mkdir_p(Path.dirname(path)),
         {:ok, file} <- File.open(path, [:append]) do
      File.close(file)
    else
      {:error, reason} ->
        raise ArgumentError,
              "LOG_FILE cannot be written: #{inspect(path)} (#{:file.format_error(reason)})"
    end
  end

  @doc """
  Parses `LOG_LEVEL` case-insensitively. Returns `:info` for `nil` or a blank value.
  Raises `ArgumentError` for any other value outside the allowed levels.
  """
  def level(value) do
    case value |> to_string() |> String.trim() |> String.downcase() do
      "" ->
        :info

      level when level in @levels ->
        String.to_existing_atom(level)

      _ ->
        raise ArgumentError,
              "LOG_LEVEL must be one of #{Enum.join(@levels, ", ")}, not #{inspect(value)}"
    end
  end
end
