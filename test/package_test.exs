defmodule PackageTest do
  use ExUnit.Case, async: true

  # `mix hex.publish` refuses a package that names a missing file, and only the release runs it.
  test "every file the package names exists" do
    for path <- Mix.Project.config()[:package][:files] do
      assert File.exists?(path), "mix.exs packages #{path}, which does not exist"
    end
  end
end
