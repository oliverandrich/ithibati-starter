defmodule ReleaseCheckTest do
  use ExUnit.Case, async: true

  @script Path.expand("../scripts/release-check.sh", __DIR__)
  @notes Path.expand("../scripts/release-notes.sh", __DIR__)
  @version "0.9.0"
  @tag_name "v#{@version}"

  # A repository with the files the check reads, committed, tagged and pushed to a bare origin.
  setup %{tmp_dir: tmp_dir} do
    work = Path.join(tmp_dir, "work")
    origin = Path.join(tmp_dir, "origin.git")
    # Nothing from the caller reaches git: not its repository, its config, or a release run's ref.
    env = [
      {"HOME", tmp_dir},
      {"XDG_CONFIG_HOME", tmp_dir},
      {"GIT_CONFIG_GLOBAL", Path.join(tmp_dir, "gitconfig")},
      {"GIT_CONFIG_NOSYSTEM", "1"},
      {"GIT_DIR", nil},
      {"GIT_WORK_TREE", nil},
      {"GIT_INDEX_FILE", nil},
      {"GITHUB_REF_TYPE", nil},
      {"GITHUB_REF_NAME", nil}
    ]

    File.mkdir_p!(work)
    git!(tmp_dir, env, ["init", "--quiet", "--bare", origin])
    git!(work, env, ["init", "--quiet"])
    git!(work, env, ["remote", "add", "origin", origin])
    write_release(work)
    git!(work, env, ["add", "."])
    git!(work, env, ["commit", "--quiet", "-m", "chore(release): #{@version}"])

    %{work: work, env: env}
  end

  @moduletag :tmp_dir

  test "a tagged, pushed and consistent release passes", %{work: work, env: env} do
    tag_and_push(work, env, @tag_name)

    assert {output, 0} = check(work, env)
    assert output =~ @tag_name
  end

  test "a pushed lightweight tag passes", %{work: work, env: env} do
    git!(work, env, ["tag", @tag_name])
    git!(work, env, ["push", "--quiet", "origin", "HEAD:refs/heads/main", @tag_name])

    assert {_output, 0} = check(work, env)
  end

  test "an archive version that differs from the starter's is refused", %{work: work, env: env} do
    replace!(work, "installer/mix.exs", ~s(version: "#{@version}"), ~s(version: "0.8.1"))
    commit_and_release(work, env)

    assert {output, 1} = check(work, env)
    assert output =~ "installer/mix.exs"
  end

  test "a version without a changelog section is refused", %{work: work, env: env} do
    replace!(work, "CHANGELOG.md", "## [#{@version}]", "## [0.8.1]")
    commit_and_release(work, env)

    assert {output, 1} = check(work, env)
    assert output =~ "CHANGELOG.md"
  end

  test "a changelog section without entries is refused", %{work: work, env: env} do
    replace!(work, "CHANGELOG.md", "- Published.\n", "")
    commit_and_release(work, env)

    assert {output, 1} = check(work, env)
    assert output =~ "CHANGELOG.md"
  end

  test "a run triggered by another tag is refused", %{work: work, env: env} do
    tag_and_push(work, env, @tag_name)
    env = env ++ [{"GITHUB_REF_TYPE", "tag"}, {"GITHUB_REF_NAME", "#{@tag_name}-rc1"}]

    assert {output, 1} = check(work, env)
    assert output =~ "#{@tag_name}-rc1"
  end

  test "the notes are the section's entries, without the link references", %{work: work} do
    assert {notes, 0} = System.cmd("bash", [@notes, @version], cd: work)
    assert notes =~ "- Published."
    refute notes =~ "Unreleased"
    refute notes =~ "compare"
  end

  test "an untagged HEAD is refused", %{work: work, env: env} do
    assert {output, 1} = check(work, env)
    assert output =~ "HEAD carries no #{@tag_name}"
  end

  test "a tag missing on origin is refused", %{work: work, env: env} do
    git!(work, env, ["tag", "-a", @tag_name, "-m", @tag_name])

    assert {output, 1} = check(work, env)
    assert output =~ "not on origin"
  end

  test "a tag that points elsewhere on origin is refused", %{work: work, env: env} do
    tag_and_push(work, env, @tag_name)
    git!(work, env, ["commit", "--quiet", "--allow-empty", "-m", "fix: later"])
    git!(work, env, ["tag", "-f", "-a", @tag_name, "-m", @tag_name])

    assert {output, 1} = check(work, env)
    assert output =~ "not at HEAD"
  end

  test "a working tree with an untracked file is refused", %{work: work, env: env} do
    tag_and_push(work, env, @tag_name)
    File.write!(Path.join(work, "stray.ex"), "")

    assert {output, 1} = check(work, env)
    assert output =~ "not clean"
  end

  defp write_release(work) do
    files = %{
      "mix.exs" => ~s(      version: "#{@version}",\n),
      "installer/mix.exs" => ~s(      version: "#{@version}",\n),
      "CHANGELOG.md" => """
      ## [Unreleased]

      ## [#{@version}] - 2026-10-18

      - Published.

      [Unreleased]: https://example.com/compare/v#{@version}...HEAD
      """
    }

    for {path, content} <- files do
      path = Path.join(work, path)
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, content)
    end
  end

  defp replace!(work, path, from, to) do
    path = Path.join(work, path)
    content = File.read!(path)
    assert content =~ from
    File.write!(path, String.replace(content, from, to))
  end

  defp commit_and_release(work, env) do
    git!(work, env, ["commit", "--quiet", "--all", "-m", "chore(release): #{@version}"])
    tag_and_push(work, env, @tag_name)
  end

  defp tag_and_push(work, env, tag) do
    git!(work, env, ["tag", "-a", tag, "-m", tag])
    git!(work, env, ["push", "--quiet", "origin", "HEAD:refs/heads/main", tag])
  end

  defp check(work, env) do
    System.cmd("bash", [@script], cd: work, env: env, stderr_to_stdout: true)
  end

  defp git!(dir, env, args) do
    identity = ["-c", "user.name=Test", "-c", "user.email=test@example.com"]
    signing = ["-c", "commit.gpgsign=false", "-c", "tag.gpgsign=false"]

    {output, status} =
      System.cmd("git", identity ++ signing ++ args, cd: dir, env: env, stderr_to_stdout: true)

    assert status == 0, output
  end
end
