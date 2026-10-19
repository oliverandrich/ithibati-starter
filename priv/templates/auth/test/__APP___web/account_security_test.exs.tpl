defmodule __MODULE__Web.AccountSecurityTest do
  use __MODULE__Web.ConnCase

  alias Ithibati.Identity.Passkeys
  alias Ithibati.Identity.RecoveryCodes
  alias __MODULE__.Accounts.User
  alias __MODULE__.Repo
  alias __MODULE__Web.Auth

  defp attrs, do: %{key_id: :crypto.strong_rand_bytes(16), public_key: :crypto.strong_rand_bytes(64)}

  setup do
    {:ok, signed} = Auth.register(build_conn() |> Plug.Test.init_test_session(%{}) |> __MODULE__.SetupSupport.authorize_conn(), attrs(), "ada", %{})
    account = Repo.get_by!(User, username: "ada")
    session = get_session(signed) |> Map.put("confirmed_at", System.system_time(:second)) |> Map.put("confirmed_account_id", account.id)
    %{conn: Plug.Test.init_test_session(build_conn(), session), account: account}
  end

  test "the settings lead to the account pages", %{conn: conn} do
    settings = conn |> get("/account/settings") |> html_response(200) |> LazyHTML.from_document()
    rows = LazyHTML.query(settings, "#settings-account a")

    assert rows |> LazyHTML.attribute("href") ==
             ["/account/passkeys", "/account/recovery-codes", "/account/invitations"]

    assert rows |> Enum.map(&(&1 |> LazyHTML.text() |> String.split())) ==
             [["Passkeys", "1"], ["Recovery", "codes", "12", "left"], ["Invitations"]]
  end

  test "each settings page leads back to the settings and marks the menu", %{conn: conn} do
    for path <- ["/account/passkeys", "/account/recovery-codes", "/account/invitations"] do
      html = conn |> get(path) |> html_response(200) |> LazyHTML.from_document()

      assert html |> LazyHTML.query("#nav-back") |> LazyHTML.attribute("href") == ["/account/settings"], path
      assert html |> LazyHTML.query("#breadcrumb a") |> LazyHTML.attribute("href") == ["/account/settings"], path
      assert html |> LazyHTML.query("#user-menu a[aria-current]") |> LazyHTML.attribute("href") == ["/account/settings"], path
    end

    assert conn |> get("/") |> html_response(200) |> LazyHTML.from_document() |> LazyHTML.query("#user-menu [aria-current]") |> Enum.empty?()
  end

  test "anonymous requests cannot read or change account security" do
    for path <- ["/account/settings", "/account/passkeys", "/account/recovery-codes", "/account/invitations"] do
      assert build_conn() |> get(path) |> redirected_to() == "/login"
    end
    assert build_conn() |> post("/account/recovery-codes", %{"confirm" => "true"}) |> redirected_to() == "/login"
    assert build_conn() |> patch("/account/passkeys/unknown", %{"label" => "Bad"}) |> redirected_to() == "/login"
    assert build_conn() |> delete("/account/passkeys/unknown") |> redirected_to() == "/login"
  end

  test "renaming and deletion are ownership scoped and preserve the last key", %{conn: conn, account: account} do
    [key] = Passkeys.list_keys(account)
    renamed = patch(conn, "/account/passkeys/#{key.id}", %{"label" => "Laptop"})
    assert redirected_to(renamed) == "/account/passkeys"
    assert [%{label: "Laptop"}] = Passkeys.list_keys(account)
    delete(conn, "/account/passkeys/#{key.id}")
    assert length(Passkeys.list_keys(account)) == 1
    other = Repo.insert!(User.changeset(%User{}, %{username: "grace"}))
    {:ok, foreign} = Passkeys.add_key(other, attrs())
    patch(conn, "/account/passkeys/#{foreign.id}", %{"label" => "Stolen"})
    delete(conn, "/account/passkeys/#{foreign.id}")
    assert [%{label: "Passkey"}] = Passkeys.list_keys(other)
    {:ok, spare} = Passkeys.add_key(account, attrs())
    delete(conn, "/account/passkeys/#{spare.id}")
    assert [%{id: id}] = Passkeys.list_keys(account)
    assert id == key.id
  end

  test "regeneration needs confirmation, invalidates old codes and shows the new batch once", %{conn: conn, account: account} do
    [old | _] = RecoveryCodes.regenerate(account)
    rejected = post(conn, "/account/recovery-codes", %{})
    assert redirected_to(rejected) == "/account/recovery-codes"
    assert {:ok, _, _} = RecoveryCodes.redeem(old)
    [old | _] = RecoveryCodes.regenerate(account)
    generated = post(conn, "/account/recovery-codes", %{"confirm" => "true"})
    assert redirected_to(generated) == "/recovery-codes"
    assert {:error, :invalid} = RecoveryCodes.redeem(old)
    [fresh | _] = get_session(generated, :recovery_codes)
    shown = generated |> recycle() |> get("/recovery-codes")
    assert html_response(shown, 200) =~ fresh
    refute get_session(shown, :recovery_codes)
    assert shown |> recycle() |> get("/recovery-codes") |> redirected_to() == "/"
  end

  test "enrollment uses the signed-in account and rechecks it on completion", %{conn: conn, account: account} do
    signed = Plug.Conn.assign(conn, :current_account, account)
    assert {:ok, ^account} = Auth.registration_subject(signed, %{"intent" => "add_passkey", "username" => "grace"})
    assert {:error, :authentication_required} = Auth.registration_subject(build_conn(), %{"intent" => "add_passkey"})
    assert {:error, :authentication_required} = Auth.register(build_conn(), attrs(), account, %{})
    other = Repo.insert!(User.changeset(%User{}, %{username: "grace"}))
    assert {:error, :authentication_required} = Auth.register(Plug.Conn.assign(conn, :current_account, other), attrs(), account, %{})
    assert {:ok, result} = Auth.register(signed, attrs(), account, %{"label" => "Phone"})
    assert json_response(result, 200)["redirect"] == "/account/passkeys"
    assert Enum.any?(Passkeys.list_keys(account), &(&1.label == "Phone"))
  end
end
