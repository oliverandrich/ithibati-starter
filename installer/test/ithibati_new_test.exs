defmodule IthibatiNewTest do
  use ExUnit.Case, async: true

  test "default command supplies Phoenix, the starter and dev-only installation" do
    assert IthibatiNew.arguments(["my_app"]) == [
             "my_app",
             "--with",
             "phx.new",
             "--install",
             "ithibati_starter@github:oliverandrich/ithibati-starter@main",
             "--only",
             "dev",
             "--with-args=--no-mailer"
           ]
  end

  test "mail uses the default Phoenix mailer without contradictory flags" do
    args =
      IthibatiNew.arguments(["my_app", "--with-mail", "--without-beans", "--yes"])

    assert "--with-mail" in args
    assert "--without-beans" in args
    assert "--yes" in args
    refute Enum.any?(args, &String.contains?(&1, "no-mailer"))
    assert Enum.count(args, &(&1 == "phx.new")) == 1
  end

  test "supports a local or pinned starter source without shell interpolation" do
    source = "ithibati_starter@path:/tmp/starter with spaces"
    args = IthibatiNew.arguments(["my_app", "--starter", source])
    assert Enum.chunk_every(args, 2, 1, :discard) |> Enum.member?(["--install", source])
  end

  test "requires one project path and refuses unsupported options" do
    for args <- [[], ["first", "second"]] do
      assert_raise Mix.Error, fn -> IthibatiNew.arguments(args) end
    end

    assert_raise OptionParser.ParseError, fn ->
      IthibatiNew.arguments(["my_app", "--with", "other.new"])
    end
  end
end
