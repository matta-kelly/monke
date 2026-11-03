#!/usr/bin/env bash
# The tests of bin/monke: how it reads a command, and the name it calls itself.
set -euo pipefail
cd "$(dirname "$0")/.."

bin=$PWD/bin/monke
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export XDG_CONFIG_HOME=$tmp/config # no person's real config
fail=0

# expect <name> <exit code> <text the output holds> <command...>
expect() {
  local name=$1 code=$2 text=$3 out got
  shift 3
  out=$("$@" 2>&1) && got=0 || got=$?
  if [ "$got" != "$code" ] || [[ $out != *"$text"* ]]; then
    echo "FAIL $name: exit $got (want $code), output: $out"
    fail=1
  else
    echo "ok   $name"
  fi
}

expect "no command prints the usage" 0 "monke status" "$bin"
expect "an unknown command fails" 2 "no command 'nope'" "$bin" nope
expect "version" 0 "monke 0.0.0" "$bin" version
for cmd in status update rollback help init; do
  expect "$cmd is not built yet" 1 "monke $cmd: not built yet" "$bin" "$cmd"
done

ln -s "$bin" "$tmp/monkey"
expect "a symlink names it" 0 "monkey status" "$tmp/monkey"

mkdir -p "$tmp/config/monke"
echo 'MONKE_MODEL=from-person' >"$tmp/config/monke/config"
expect "the person's config is read" 0 "from-person" bash -c ". '$bin' version >/dev/null; echo \$MONKE_MODEL"

exit $fail
