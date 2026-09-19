#!/usr/bin/env bash
set -euo pipefail

starter_root=$(cd "$(dirname "$0")/.." && pwd)
fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/ithibati-starter.XXXXXX")
trap 'rm -rf "$fixture_root"' EXIT
unset MIX_ENV
export MIX_TEST_PARTITION="_starter_$$"
export PORT="${PORT:-43129}"

# Keep archive installation isolated from the developer's installed generators.
archive_source="${MIX_ARCHIVES:-$HOME/.mix/archives}"
mkdir -p "$fixture_root/archives"
for archive in "$archive_source"/*; do
  [[ -e "$archive" ]] || continue
  [[ "$(basename "$archive")" == ithibati_new-* ]] && continue
  ln -s "$archive" "$fixture_root/archives/$(basename "$archive")"
done
export MIX_ARCHIVES="$fixture_root/archives"
mix archive.install hex phx_new 1.8.14 --force
mix archive.install hex igniter_new 0.5.34 --force
(cd "$starter_root/installer" && mix archive.build -o "$fixture_root/ithibati_new.ez")
mix archive.install "$fixture_root/ithibati_new.ez" --force

for profile in auth mail; do
  app="starter_${profile}"
  target="$fixture_root/$app"
  options=(--yes)
  if [[ "$profile" == mail ]]; then
    options=(--yes --with-mail --without-beans)
  fi

  (cd "$fixture_root" && mix ithibati.new "$target" --starter "ithibati_starter@path:$starter_root" "${options[@]}")
  (
    cd "$target"
    mise trust
    mise install
    mise run check
    # The second run must preserve the generated sources and any later user edits.
    mix ithibati_starter.install --dry-run "${options[@]}"
    if [[ "$profile" == mail ]]; then
      test -e "lib/$app/mailer.ex"
      test ! -e .beans.yml
      test -e "test/${app}_web/invitation_mail_test.exs"
    fi
    MIX_ENV=prod mix compile --warnings-as-errors
  )
done
