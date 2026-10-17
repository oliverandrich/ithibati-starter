defmodule __MODULE__.Logging do
  @moduledoc """
  Production logging: one JSON object per line on stdout, at `LOG_LEVEL`.

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
  The formatter would log its path, which may hold an invitation token, and the client's address
  and user agent.
  """
  def drop_request(%{meta: meta} = event, _config), do: %{event | meta: Map.delete(meta, :conn)}

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
