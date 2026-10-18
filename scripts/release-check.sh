#!/usr/bin/env bash
# Refuses a release that is not exactly the commit a pushed version tag points at.
set -euo pipefail

fail() {
  echo "release-check: $1" >&2
  exit 1
}

# Read as text, because loading the project through Mix needs Hex and its dependencies.
read_version() {
  sed -n 's/^      version: "\([^"]*\)",$/\1/p' "$1"
}

version=$(read_version mix.exs)
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "read \"$version\" from mix.exs, which is not a version"

archive=$(read_version installer/mix.exs)
[[ "$archive" == "$version" ]] || fail "installer/mix.exs has version \"$archive\", mix.exs has \"$version\""

# The announce job publishes these notes after Hex, so an empty section must stop the release here.
bash "$(dirname "$0")/release-notes.sh" "$version" >/dev/null || fail "CHANGELOG.md has no entries for $version"

# Untracked files count, because the package takes lib/, priv/ and docs/ by glob.
[[ -z "$(git status --porcelain)" ]] || fail "the working tree is not clean"

tag="v$version"
# A release run publishes the version its tag names, so that tag must be this one.
if [[ "${GITHUB_REF_TYPE:-}" == tag && "${GITHUB_REF_NAME:-}" != "$tag" ]]; then
  fail "the run was triggered by $GITHUB_REF_NAME, but mix.exs has $version"
fi
git tag --points-at HEAD | grep -qx "$tag" || fail "HEAD carries no $tag. Tag it first: git tag -a $tag -m $tag"

# An annotated tag lists its commit last, under ^{}; a lightweight tag lists only itself.
remote=$(git ls-remote origin "refs/tags/$tag" "refs/tags/$tag^{}" | tail -n 1 | cut -f1)
[[ -n "$remote" ]] || fail "$tag is not on origin. Push it: git push origin $tag"
[[ "$remote" == "$(git rev-parse HEAD)" ]] || fail "origin's $tag points at $remote, not at HEAD"

echo "release-check: $tag is on origin, and both packages and the changelog name $version"
