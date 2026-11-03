#!/usr/bin/env bash
# The tests of bin/monke. Every tool it calls is a stub on PATH, so nothing here touches the machine, the network or a
# vault. Each stub logs its call to $tmp/log.
# The stubs' bodies are code for the stub, in single quotes on purpose.
# shellcheck disable=SC2016
set -euo pipefail
cd "$(dirname "$0")/.."

bin=$PWD/bin/monke
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export XDG_CONFIG_HOME=$tmp/config HOME=$tmp/home
mkdir -p "$tmp/stub" "$XDG_CONFIG_HOME/monke" "$HOME"
fail=0

# stub <tool> [body]: a tool that logs its call, then runs body (default: exit 0).
stub() {
  printf '#!/usr/bin/env bash\necho "%s $*" >>"%s/log"\n%s\n' "$1" "$tmp" "${2:-exit 0}" >"$tmp/stub/$1"
  chmod +x "$tmp/stub/$1"
}
for tool in rpm-ostree flatpak tailscale rbw gh chezmoi restic systemctl; do stub "$tool"; done
export PATH=$tmp/stub:$PATH

# expect <name> <exit code> <text the output holds> <command...>
expect() {
  local name=$1 code=$2 text=$3 out got
  shift 3
  : >"$tmp/log"
  out=$("$@" 2>&1 </dev/null) && got=0 || got=$?
  if [ "$got" != "$code" ] || [[ $out != *"$text"* ]]; then
    printf 'FAIL %s: exit %s (want %s), output:\n%s\n' "$name" "$got" "$code" "$out"
    fail=1
  else
    echo "ok   $name"
  fi
}
# logged <name> <text>: the stubs' log holds text.
logged() {
  if grep -qF -- "$2" "$tmp/log"; then echo "ok   $1"; else
    printf 'FAIL %s: log has no "%s":\n%s\n' "$1" "$2" "$(cat "$tmp/log")"
    fail=1
  fi
}

# The command line
expect "no command prints the usage" 0 "monke status" "$bin"
expect "an unknown command fails" 2 "no command 'nope'" "$bin" nope
expect "version" 0 "monke 0.1.0" "$bin" version
ln -s "$bin" "$tmp/monkey"
expect "a symlink names it" 0 "monkey status" "$tmp/monkey"

# status, update, rollback
expect "status prints what it runs" 0 "+ rpm-ostree status" "$bin" status
logged "status lists the apps" "flatpak list --app"
expect "update: the system, then the apps" 0 "+ flatpak update -y" "$bin" update
logged "update upgrades the system" "rpm-ostree upgrade"
stub rpm-ostree '[ "$2" = --pending-exit-77 ] && exit 77; exit 0'
expect "update says when a system is staged" 0 "Reboot to use it" "$bin" update
stub rpm-ostree
expect "rollback" 0 "+ rpm-ostree rollback" "$bin" rollback

# help
docs=$tmp/docs
mkdir -p "$docs"
echo "Sway is the window manager." >"$docs/desktop.md"
printf 'sk-secret-123\n' >"$tmp/key"
cat >"$XDG_CONFIG_HOME/monke/config" <<EOF
MONKE_DOCS=$docs
MONKE_ENDPOINT=https://llm.example/v1
MONKE_MODEL=test-model
MONKE_KEY_FILE=$tmp/key
EOF
# curl: saves the request body and headers, and answers.
stub curl 'cat >"'"$tmp"'/body"; for a; do case $a in @/dev/fd/*) cat "${a#@}" >"'"$tmp"'/headers";; esac; done
echo "{\"choices\":[{\"message\":{\"content\":\"Use sway.\"}}]}"'
expect "help prints the answer" 0 "Use sway." "$bin" help "what is the window manager"
expect "help never prints the key" 0 "the key from $tmp/key" "$bin" help "x"
if grep -q sk-secret "$tmp/log"; then echo "FAIL the key is on curl's command line"; fail=1; else echo "ok   the key is not on curl's command line"; fi
if grep -q "Bearer sk-secret-123" "$tmp/headers"; then echo "ok   the key is in the header"; else
  echo "FAIL no key in the header"; fail=1
fi
if jq -e '.model == "test-model" and (.messages[0].content | contains("Sway is the window manager")) and .messages[1].content == "x"' "$tmp/body" >/dev/null; then
  echo "ok   the request holds the model, the docs and the question"
else echo "FAIL the request body"; fail=1; fi
expect "help with no question" 2 "usage:" "$bin" help
stub curl 'echo "{\"error\":\"bad key\"}"; exit 22'
expect "help says when the request fails" 1 "bad key" "$bin" help "x"
echo "MONKE_MODEL=" >>"$XDG_CONFIG_HOME/monke/config"
expect "help with no model" 1 "no MONKE_MODEL" "$bin" help "x"
rm "$XDG_CONFIG_HOME/monke/config"

# init
stub tailscale 'exit 1'
expect "init stops off the mesh" 1 "not on the mesh" "$bin" init
stub tailscale
mkdir -p "$tmp/src/.git"
stub chezmoi 'echo '"$tmp"'/src'
expect "init with no backup config says what to make" 0 "a vault item restic-" "$bin" init
logged "init checks the vault" "rbw unlocked"
logged "init checks GitHub" "gh auth status"
mkdir -p "$XDG_CONFIG_HOME/restic"
echo "RESTIC_REPOSITORY=s3:example" >"$XDG_CONFIG_HOME/restic/env"
echo pw >"$XDG_CONFIG_HOME/restic/password"
stub restic '[ "$3" = snapshots ] && echo "[{\"id\":\"a\"}]"; exit 0'
expect "init with everything done changes nothing" 0 "Done." "$bin" init
if grep -qE '^(rbw login|gh auth login|chezmoi init|restic .* init|systemctl)' "$tmp/log"; then
  echo "FAIL init changed something"; fail=1
else echo "ok   init changed nothing"; fi

exit $fail
