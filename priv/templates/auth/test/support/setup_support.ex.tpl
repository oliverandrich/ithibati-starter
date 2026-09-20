defmodule __MODULE__.SetupSupport do
  @moduledoc false

  alias Ithibati.Identity.Instance

  def authorize_conn(conn) do
    {:ok, code} = Instance.issue_code()
    {:ok, authorization} = Instance.authorize_code(code)
    Plug.Conn.put_session(conn, :initial_setup_authorization, authorization)
  end
end
