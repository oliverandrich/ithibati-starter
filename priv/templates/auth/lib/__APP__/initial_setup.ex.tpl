defmodule __MODULE__.InitialSetup do
  @moduledoc """
  Operator-issued authorization for the first account claim.

  The code is shown only by an explicit operator command. Its digest lives in the database until
  the claim transaction consumes it. A short-lived session authorization carries the digest, not
  the code, and becomes invalid when the operator issues a replacement code.
  """
  use Ecto.Schema

  import Ecto.Query

  alias Ithibati.Identity.Instance
  alias __MODULE__.Repo

  @authorization_seconds 600

  schema "initial_setup_codes" do
    field :digest, :binary
    timestamps(type: :utc_datetime_usec)
  end

  @doc "Generate or replace the first-account code; no account may have claimed the instance."
  def issue_code do
    code = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
    digest = :crypto.hash(:sha256, code)

    Repo.transaction(fn ->
      if not Instance.needs_setup?(), do: Repo.rollback(:already_claimed)

      Repo.insert!(%__MODULE__.InitialSetup{id: 1, digest: digest},
        on_conflict: {:replace, [:digest, :updated_at]},
        conflict_target: :id
      )

      if Instance.needs_setup?(), do: code, else: Repo.rollback(:already_claimed)
    end)
  end

  @doc "Print a new code to the operator's terminal from `mise run setup-code` or `bin/setup-code`."
  def print_code! do
    {:ok, _started} = Application.ensure_all_started(:__APP__)

    case issue_code() do
      {:ok, code} ->
        IO.puts("Initial setup code: #{code}")

      {:error, :already_claimed} ->
        raise "the first account has already claimed this instance"
    end
  end

  @doc "Exchange the operator code for a short-lived session authorization."
  def authorize(code) when is_binary(code) do
    case Repo.get(__MODULE__.InitialSetup, 1) do
      %__MODULE__.InitialSetup{digest: digest} when byte_size(code) > 0 ->
        candidate = :crypto.hash(:sha256, String.trim(code))

        if Plug.Crypto.secure_compare(candidate, digest) and Instance.needs_setup?() do
          {:ok, %{digest: digest, expires_at: System.system_time(:second) + @authorization_seconds}}
        else
          {:error, :invalid_setup_code}
        end

      _ ->
        {:error, :invalid_setup_code}
    end
  end

  def authorize(_code), do: {:error, :invalid_setup_code}

  @doc "Scope attempt budgets to the current code, so replacing a code resets its budget."
  def current_digest do
    case Repo.get(__MODULE__.InitialSetup, 1) do
      %__MODULE__.InitialSetup{digest: digest} -> digest
      nil -> nil
    end
  end

  @doc "Check the current database code and expiry before starting a passkey ceremony."
  def authorized_session?(session) when is_map(session) do
    authorization = Map.get(session, "initial_setup_authorization") || Map.get(session, :initial_setup_authorization)

    valid_authorization?(authorization, Repo.get(__MODULE__.InitialSetup, 1))
  end

  @doc "Consume the code inside the same transaction that claims the instance."
  def consume(repo, authorization) do
    current = repo.one(from setup in __MODULE__.InitialSetup, where: setup.id == 1, lock: "FOR UPDATE")

    if valid_authorization?(authorization, current) do
      case repo.delete(current) do
        {:ok, _deleted} -> {:ok, :authorized}
        {:error, _changeset} -> {:error, :setup_authorization_required}
      end
    else
      {:error, :setup_authorization_required}
    end
  end

  defp valid_authorization?(authorization, %__MODULE__.InitialSetup{digest: stored}) do
    case authorization do
      %{digest: digest, expires_at: expires_at} -> valid_digest?(digest, expires_at, stored)
      %{"digest" => digest, "expires_at" => expires_at} -> valid_digest?(digest, expires_at, stored)
      _ -> false
    end
  end

  defp valid_authorization?(_authorization, _missing), do: false

  defp valid_digest?(digest, expires_at, stored)
       when is_binary(digest) and is_integer(expires_at) and byte_size(digest) == 32,
       do: expires_at > System.system_time(:second) and Plug.Crypto.secure_compare(digest, stored)

  defp valid_digest?(_digest, _expires_at, _stored), do: false
end
