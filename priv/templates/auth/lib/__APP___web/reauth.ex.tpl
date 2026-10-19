defmodule __MODULE__Web.Reauth do
  @moduledoc "Five-minute confirmation bound to the current session account."
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  # The pages a confirmation returns to, by the purpose in `/account/confirm/:purpose`.
  @targets %{
    "passkeys" => "/account/passkeys",
    "recovery-codes" => "/account/recovery-codes",
    "accounts" => "/accounts"
  }

  @paths Map.values(@targets)

  @doc "Returns `{:ok, path}` for a known purpose, else `:error`."
  def target(purpose), do: Map.fetch(@targets, purpose)

  @doc "Returns whether `path` is a page a confirmation returns to."
  def target?(path), do: path in @paths

  def recent?(session, account) do
    case {session["confirmed_account_id"], session["confirmed_at"]} do
      {id, at} when id == account.id and is_integer(at) ->
        age = System.system_time(:second) - at
        age >= 0 and age <= 300
      _ -> false
    end
  end

  def confirmed?(conn), do: recent?(get_session(conn), conn.assigns.current_account)

  def pending?(conn), do: not is_nil(conn.assigns[:current_account]) and target?(get_session(conn, :reauth_target))

  def complete(conn, account, codes \\ nil) do
    case conn.assigns[:current_account] do
      %{id: id} when id == account.id ->
        target = get_session(conn, :reauth_target)
        conn = conn |> delete_session(:reauth_target) |> put_session(:confirmed_account_id, id) |> put_session(:confirmed_at, System.system_time(:second))
        conn = if codes, do: put_session(conn, :recovery_codes, codes), else: conn
        {:ok, json(conn, %{redirect: if(codes, do: "/recovery-codes", else: target)})}
      _ -> {:error, :account_mismatch}
    end
  end
end
