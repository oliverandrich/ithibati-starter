defmodule __MODULE__.LoggingTest do
  @moduledoc "The production log format: one JSON object per line, with allowlisted metadata only."
  # RuntimeConfig sets environment variables, which are global.
  use ExUnit.Case, async: false

  alias __MODULE__.Logging
  alias __MODULE__.RuntimeConfig

  defp format(event) do
    {formatter, config} = Logging.formatter()
    event |> formatter.format(config) |> IO.iodata_to_binary()
  end

  test "a line is JSON and carries only the metadata the application allows" do
    line =
      format(%{
        level: :warning,
        msg: {:string, "something failed"},
        meta: %{time: System.os_time(:microsecond), request_id: "req-1", username: "grace_hopper"}
      })

    assert String.ends_with?(line, "\n")
    decoded = JSON.decode!(line)

    assert decoded["message"] == "something failed"
    assert decoded["severity"] == "warning"
    assert decoded["metadata"]["request_id"] == "req-1"
    refute line =~ "grace_hopper"
  end

  # Bandit attaches the conn to a crash report. A path may hold identifiers or codes.
  test "a request that crashes reaches the line without its path, address or agent" do
    conn =
      Plug.Test.conn(:get, "/account/confirm/a-secret-token")
      |> Plug.Conn.put_req_header("user-agent", "Probe/1")

    line =
      %{
        level: :error,
        msg: {:string, "request crashed"},
        meta: %{time: System.os_time(:microsecond), conn: conn}
      }
      |> Logging.drop_request(nil)
      |> format()

    refute line =~ "a-secret-token"
    refute line =~ "Probe/1"
    refute line =~ "127.0.0.1"
  end

  # Supplied filters replace Logger's default, which keeps remote shells' events off stdout.
  test "the handler keeps Logger's remote group leader filter beside its own" do
    assert Logging.filters()[:remote_gl] == {&:logger_filters.remote_gl/2, :stop}
    assert {_filter, nil} = Logging.filters()[:drop_request]
  end

  test "a production boot reads LOG_LEVEL and installs the JSON handler" do
    config = RuntimeConfig.read(:prod, %{"LOG_LEVEL" => "warning"})

    assert config[:logger][:level] == :warning
    assert config[:logger][:default_handler][:formatter] == Logging.formatter()
    assert config[:logger][:default_handler][:filters] == Logging.filters()
  end

  # `debug` enables LiveView and Ecto logs, which include session data and query parameters.
  test "the level comes from LOG_LEVEL, info unless it says otherwise, and never debug" do
    assert Logging.level(nil) == :info
    assert Logging.level("") == :info
    assert Logging.level(" Warning ") == :warning
    assert Logging.level("ERROR") == :error
    assert_raise ArgumentError, fn -> Logging.level("debug") end
    assert_raise ArgumentError, fn -> Logging.level("loud") end
  end
end
