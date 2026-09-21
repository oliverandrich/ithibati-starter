defmodule IthibatiNewTest do
  use ExUnit.Case, async: true

  @pinned_starter "ithibati_starter@github:oliverandrich/ithibati-starter@v0.4.0"

  test "default command supplies Phoenix, the starter and dev-only installation" do
    assert IthibatiNew.arguments(["my_app"]) == [
             "my_app",
             "--with",
             "phx.new",
             "--install",
             @pinned_starter,
             "--only",
             "dev",
             "--yes"
           ]
  end

  test "archive version identifies the pinned default" do
    assert IthibatiNew.MixProject.project()[:version] == "0.4.0"
  end

  test "accepts installation prompts by default" do
    for options <- [[], ["--without-beans"]] do
      assert "--yes" in IthibatiNew.arguments(["my_app" | options])
      refute "--yes" in IthibatiNew.arguments(["my_app", "--no-yes" | options])
    end
  end

  # Every application ships the mailer, so nothing asks Phoenix to leave it out.
  test "the Phoenix mailer is kept, and no flag contradicts it" do
    args = IthibatiNew.arguments(["my_app", "--without-beans", "--yes"])

    assert "--without-beans" in args
    assert "--yes" in args
    refute Enum.any?(args, &String.contains?(&1, "mailer"))
    assert Enum.count(args, &(&1 == "phx.new")) == 1
  end

  test "an option this archive no longer has is refused" do
    assert_raise OptionParser.ParseError, fn ->
      IthibatiNew.arguments(["my_app", "--with-mail"])
    end
  end

  test "supports a local or pinned starter source without shell interpolation" do
    for source <- [
          "ithibati_starter@path:/tmp/starter with spaces",
          "ithibati_starter@github:oliverandrich/ithibati-starter@aadf7562ac7a24cd98f1af91d27d8654c298ca4a"
        ] do
      args = IthibatiNew.arguments(["my_app", "--starter", source])
      assert Enum.chunk_every(args, 2, 1, :discard) |> Enum.member?(["--install", source])
    end
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
