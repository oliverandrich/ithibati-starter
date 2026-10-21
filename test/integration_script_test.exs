defmodule IntegrationScriptTest do
  use ExUnit.Case, async: true

  @script Path.expand("../scripts/integration.sh", __DIR__)

  # CI passes the profiles by name. A typo must stop the run before it installs anything.
  test "an unknown profile is refused" do
    assert {output, 1} = System.cmd("bash", [@script, "mit", "gpl"], stderr_to_stdout: true)
    assert output =~ "Unknown profile gpl; use mit or agpl"
  end

  # An image check that cannot run must fail, not pass by skipping.
  @tag :tmp_dir
  test "an image check without docker is refused", %{tmp_dir: empty} do
    env = [{"INTEGRATION_IMAGE", "true"}, {"PATH", empty}]

    assert {output, 1} =
             System.cmd("bash", [@script, "agpl"], env: env, stderr_to_stdout: true)

    assert output =~ "INTEGRATION_IMAGE=true needs the docker command"
  end
end
