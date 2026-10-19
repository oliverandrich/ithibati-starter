defmodule __MODULE__.GrantAdminTest do
  use __MODULE__.DataCase, async: true

  import ExUnit.CaptureIO

  alias __MODULE__.Accounts.User
  alias __MODULE__.GrantAdmin

  # The operator's way back when an instance has no administrator left.
  test "makes an account an administrator and names an unknown one" do
    member = Repo.insert!(%User{username: "ada"})

    # The output names the account as stored, not as typed.
    printed = capture_io(fn -> assert GrantAdmin.run(" ADA ") == :ok end)
    assert printed == "ada is an administrator.\n"
    assert Repo.reload!(member).admin

    printed = capture_io(fn -> assert GrantAdmin.run(" Nobody ") == {:error, :not_found} end)
    assert printed == "No account is named nobody. Nothing changed.\n"
  end
end
