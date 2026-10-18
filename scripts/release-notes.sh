#!/usr/bin/env bash
# Prints the CHANGELOG.md section of a version, or fails when it has no entries.
set -euo pipefail

version="$1"

# Link references at the end of the file close the oldest section.
notes=$(awk -v ver="$version" '
  index($0, "## [" ver "]") == 1 { found = 1; next }
  found && /^(## |\[[^]]+\]: )/ { exit }
  found { print }
' CHANGELOG.md)

if ! grep -q '[^[:space:]]' <<<"$notes"; then
  echo "CHANGELOG.md has no entries under \"## [$version]\"" >&2
  exit 1
fi

printf '%s\n' "$notes"
