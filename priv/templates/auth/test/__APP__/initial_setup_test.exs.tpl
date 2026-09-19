defmodule __MODULE__.InitialSetupTest do
  use __MODULE__.DataCase, async: true

  alias __MODULE__.InitialSetup

  test "issues a strong code, stores only its digest and prints it only on request" do
    output = ExUnit.CaptureIO.capture_io(fn -> assert :ok = InitialSetup.print_code!() end)
    ["Initial setup code: " <> code] = String.split(String.trim(output), "\n")

    assert byte_size(Base.url_decode64!(code, padding: false)) == 32
    assert Repo.get!(InitialSetup, 1).digest == :crypto.hash(:sha256, code)
    refute output =~ inspect(Repo.get!(InitialSetup, 1).digest)
    assert {:ok, _authorization} = InitialSetup.authorize(code)
    assert {:error, :invalid_setup_code} = InitialSetup.authorize("wrong")
  end

  test "a newly issued code invalidates the old code and its session authorization" do
    assert {:ok, old_code} = InitialSetup.issue_code()
    assert {:ok, authorization} = InitialSetup.authorize(old_code)
    assert InitialSetup.authorized_session?(%{"initial_setup_authorization" => authorization})

    assert {:ok, new_code} = InitialSetup.issue_code()
    assert {:error, :invalid_setup_code} = InitialSetup.authorize(old_code)
    refute InitialSetup.authorized_session?(%{"initial_setup_authorization" => authorization})
    assert {:ok, _authorization} = InitialSetup.authorize(new_code)
  end

  test "expired authorization is refused" do
    assert {:ok, code} = InitialSetup.issue_code()
    assert {:ok, authorization} = InitialSetup.authorize(code)
    expired = %{authorization | expires_at: System.system_time(:second) - 1}

    refute InitialSetup.authorized_session?(%{"initial_setup_authorization" => expired})
  end
end
