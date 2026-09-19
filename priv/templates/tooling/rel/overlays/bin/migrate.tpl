#!/bin/sh
set -eu

cd -P -- "$(dirname -- "$0")"
exec ./__APP__ eval "__MODULE__.Release.migrate()"
