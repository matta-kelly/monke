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
export XDG_CONFIG_HOME=$tmp/config XDG_STATE_HOME=$tmp/state HOME=$tmp/home
mkdir -p "$tmp/stub" "$XDG_CONFIG_HOME/monke" "$HOME"
fail=0

# stub <tool> [body]: a tool that logs its call, then runs body (default: exit 0).
stub() {
  printf '#!/usr/bin/env bash\necho "%s $*" >>"%s/log"\n%s\n' "$1" "$tmp" "${2:-exit 0}" >"$tmp/stub/$1"
  chmod +x "$tmp/stub/$1"
}
for tool in rpm-ostree flatpak tailscale rbw gh chezmoi restic systemctl nmcli; do stub "$tool"; done
export PATH=$tmp/stub:$PATH

# expect <name> <exit code> <text the output holds> <command...>
expect() {
  local name=$1 code=$2 text=$3 out got
  shift 3
  : >"$tmp/log"
  out=$("$@" 2>&1 <<<"${input-}") && got=0 || got=$?
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
expect "version" 0 "monke dev" "$bin" version
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
share=$PWD/share/monke
docs=$tmp/docs
mkdir -p "$docs"
echo "Sway is the window manager." >"$docs/desktop.md"
printf 'sk-secret-123\n' >"$tmp/key"
echo model >"$tmp/model.gguf"
cat >"$XDG_CONFIG_HOME/monke/config" <<EOF
MONKE_DOCS=$docs
MONKE_SHARE=$share
MONKE_MAIN_MODEL=test-main
MONKE_KEY_FILE=$tmp/key
MONKE_LOCAL_MODEL=$tmp/model.gguf
MONKE_KEYS=$tmp/keys
EOF
printf '#!/bin/sh\necho "Super+q: kill"\n' >"$tmp/keys"
chmod +x "$tmp/keys"
# pi: logs its arguments, whether it got a key, and its system prompt.
stub pi 'echo "pi key=${FIREWORKS_API_KEY:+set} dir=${PI_CODING_AGENT_DIR:-own}" >>"'"$tmp"'/log"
while [ $# -gt 0 ]; do [ "$1" = --append-system-prompt ] && cp "$2" "'"$tmp"'/system.md"; shift; done'
stub llama-server 'echo $$ >"'"$tmp"'/server.pid"; exec sleep 30'
stub curl 'exit 0'
stub nmcli 'echo full'

input="" expect "online, Enter picks local" 0 "+ pi --no-tools --provider local --model local" "$bin" help
if grep -q "offline" "$tmp/system.md"; then echo "FAIL online local got the wifi offer"; fail=1; else echo "ok   online local has no wifi offer"; fi
if grep -q "Super+q: kill" "$tmp/system.md"; then echo "ok   local has the key bindings"; else echo "FAIL local has no key bindings"; fail=1; fi
logged "local starts llama-server on the model" "llama-server -m $tmp/model.gguf"
logged "local uses its own pi config" "dir=$XDG_STATE_HOME"
if kill -0 "$(cat "$tmp/server.pid")" 2>/dev/null; then echo "FAIL llama-server left running"; fail=1; else echo "ok   llama-server stops when help ends"; fi

input="m" expect "online, m picks main" 0 "+ pi --no-tools --provider fireworks --model test-main" "$bin" help "how do I add an app"
logged "main gets the key in its environment" "pi key=set dir=own"
logged "main passes the question" "how do I add an app"
if grep -q sk-secret "$tmp/log"; then echo "FAIL the key is on pi's command line"; fail=1; else echo "ok   the key is not on pi's command line"; fi
if grep -q "Sway is the window manager" "$tmp/system.md"; then echo "ok   main has the docs"; else echo "FAIL main has no docs"; fail=1; fi
if grep -q "Super+q: kill" "$tmp/system.md"; then echo "ok   main has the key bindings"; else echo "FAIL main has no key bindings"; fail=1; fi

stub nmcli 'echo none'
expect "offline goes local without asking" 0 "offline (none): using the local model" "$bin" help
if grep -q "first reply" "$tmp/system.md"; then echo "ok   offline local opens with the wifi offer"; else echo "FAIL no wifi offer offline"; fail=1; fi
logged "offline with no question, local speaks first" "I'm offline."

rm "$tmp/model.gguf"
expect "local with no model says how it comes" 1 "It downloads by itself once the machine is online" "$bin" help
stub llama-server 'exit 1'
stub curl 'exit 7'
echo model >"$tmp/model.gguf"
expect "a server that dies is reported" 1 "llama-server stopped" "$bin" help
rm "$XDG_CONFIG_HOME/monke/config"
stub nmcli

# monke-keys: reads sway's config the way sway layers it
fake=$tmp/fakeroot
mkdir -p "$fake/etc/sway/config.d" "$fake/usr/share/sway/config.d" "$tmp/kx/sway/config.d"
printf 'set $mod Mod4\nset $term foot\n# a comment\nbindsym $mod+Return exec $term\nbindsym $mod+d exec rofi \\\n  -show drun\nmode "resize" {\n  bindsym Escape mode "default"\n}\n' >"$fake/etc/sway/config"
printf 'bindsym --locked {\n  XF86AudioMute exec pactl mute\n}\n' >"$fake/usr/share/sway/config.d/60-volume.conf"
printf 'bindsym $mod+o exec shared\n' >"$fake/etc/sway/config.d/70-keys.conf"
printf 'bindsym $mod+o exec thunar\n' >"$tmp/kx/sway/config.d/70-keys.conf"
keys=$(MONKE_SWAY_ROOT=$fake XDG_CONFIG_HOME=$tmp/kx "$PWD/libexec/monke-keys")
for want in "Super+Return: exec foot" "Super+d: exec rofi -show drun" "[resize mode] Escape: mode \"default\"" "XF86AudioMute: exec pactl mute" "Super+o: exec thunar"; do
  if grep -qF -- "$want" <<<"$keys"; then echo "ok   keys: $want"; else printf 'FAIL keys: no "%s" in:\n%s\n' "$want" "$keys"; fail=1; fi
done
if grep -q "exec shared" <<<"$keys"; then echo "FAIL keys: a person's drop-in does not replace the shared one"; fail=1; else echo "ok   keys: a person's drop-in replaces the shared one"; fi

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
