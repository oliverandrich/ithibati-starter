defmodule __MODULE__.SetupSupport do
  @moduledoc false

  alias __MODULE__.InitialSetup

  def authorize_conn(conn) do
    {:ok, code} = InitialSetup.issue_code()
    {:ok, authorization} = InitialSetup.authorize(code)
    Plug.Conn.put_session(conn, :initial_setup_authorization, authorization)
  end
end
