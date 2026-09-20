defmodule __MODULE__.InitialSetupTest do
  use __MODULE__.DataCase, async: true

  alias Ithibati.Identity.Instance
  alias __MODULE__.InitialSetup

  test "prints a strong Ithibati code only on request" do
    output = ExUnit.CaptureIO.capture_io(fn -> assert :ok = InitialSetup.print_code!() end)
    ["Initial setup code: " <> code] = String.split(String.trim(output), "\n")

    assert byte_size(Base.url_decode64!(code, padding: false)) == 32
    assert {:ok, proof} = Instance.authorize_code(code)
    assert Instance.authorized?(proof)
    assert {:error, :invalid_setup_code} = Instance.authorize_code("wrong")
  end

  test "a newly issued code invalidates an earlier authorization" do
    assert {:ok, old_code} = Instance.issue_code()
    assert {:ok, proof} = Instance.authorize_code(old_code)
    assert Instance.authorized?(proof)

    assert {:ok, new_code} = Instance.issue_code()
    assert {:error, :invalid_setup_code} = Instance.authorize_code(old_code)
    refute Instance.authorized?(proof)
    assert {:ok, _proof} = Instance.authorize_code(new_code)
  end

  test "expired authorization is refused" do
    assert {:ok, code} = Instance.issue_code()
    assert {:ok, proof} = Instance.authorize_code(code)
    expired = %{proof | expires_at: System.system_time(:second) - 1}

    refute Instance.authorized?(expired)
  end
end
