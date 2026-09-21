defmodule __MODULE__Web.SetupControllerTest do
  use __MODULE__Web.ConnCase

  alias Ithibati.Identity.Instance


  test "missing and invalid codes cannot unlock setup", %{conn: conn} do
    {:ok, code} = Instance.issue_code()

    for params <- [%{}, %{"setup_code" => "wrong"}] do
      response = post(conn, "/setup/authorize", params)
      assert redirected_to(response) == "/setup"
      refute get_session(response, :initial_setup_authorization)
      refute inspect(response.resp_headers) =~ code
    end
  end

  test "a valid code unlocks setup without putting the code in the response", %{conn: conn} do
    {:ok, code} = Instance.issue_code()
    response = post(conn, "/setup/authorize", %{"setup_code" => code})

    assert redirected_to(response) == "/setup"
    assert get_session(response, :initial_setup_authorization)
    refute inspect(response.resp_headers) =~ code
    assert response |> recycle() |> get("/setup") |> html_response(200) =~ "claim-form"
  end

  test "limits setup-code guesses before accepting even the correct code", %{conn: conn} do
    __MODULE__.SetupSupport.put_budget(:setup, {10, 60})
    {:ok, code} = Instance.issue_code()
    ip = {192, 0, 2, rem(System.unique_integer([:positive]), 254) + 1}
    conn = %{conn | remote_ip: ip}

    for _ <- 1..10 do
      response = post(conn, "/setup/authorize", %{"setup_code" => "wrong"})
      assert redirected_to(response) == "/setup"
      assert get_resp_header(response, "retry-after") == []
    end

    limited = post(conn, "/setup/authorize", %{"setup_code" => code})
    assert redirected_to(limited) == "/setup"
    assert get_resp_header(limited, "retry-after") != []
    refute get_session(limited, :initial_setup_authorization)

    {:ok, replacement} = Instance.issue_code()
    still_limited = post(conn, "/setup/authorize", %{"setup_code" => replacement})
    assert get_resp_header(still_limited, "retry-after") != []
    refute get_session(still_limited, :initial_setup_authorization)
  end

  test "uses the configured setup-code limit", %{conn: conn} do
    __MODULE__.SetupSupport.put_budget(:setup, {1, 60})

    {:ok, code} = Instance.issue_code()
    ip = {198, 51, 100, rem(System.unique_integer([:positive]), 254) + 1}
    conn = %{conn | remote_ip: ip}

    assert redirected_to(post(conn, "/setup/authorize", %{"setup_code" => "wrong"})) == "/setup"
    blocked = post(conn, "/setup/authorize", %{"setup_code" => code})
    assert get_resp_header(blocked, "retry-after") != []
    refute get_session(blocked, :initial_setup_authorization)
  end

  test "the code submission requires a CSRF token", %{conn: conn} do
    {:ok, code} = Instance.issue_code()

    assert_error_sent(403, fn ->
      conn
      |> Plug.Conn.put_private(:plug_skip_csrf_protection, false)
      |> post("/setup/authorize", %{"setup_code" => code})
    end)
  end
end
