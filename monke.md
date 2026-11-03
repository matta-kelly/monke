---
type: component
description: "monke, the CLI of Monkeyworks: one bash script that wraps the machine's own tools and prints each command it runs. Its commands, help's chat with a local or a main model, its config, how each person names it, and how the image ships it. Read before changing the CLI, help's models, or how the image ships it."
status: planned
---
monke: the front door of [[monkeyworks]]. A bash script that wraps the tools the machine already has, and prints each command before it runs it, so the user sees what it does and can do it by hand.
- Commands: what each one does
- Help: the chat, its two models, and how each runs
- Config: where its values come from
- Names: how each person calls it by their own name
- How the image ships it

Built: every command, the config, the local model's download, the release, and the tests. Run for real: `help` on the local path, in the published image, with a tiny test model. Not yet run on a real machine.

---
## Commands

Each command prints what it runs: `+ cmd` for a command that does something, `? cmd` for a check that changes nothing.
- `status`: `rpm-ostree status` (the booted, staged and rollback systems), the installed apps, and the app updates there are
- `update`: `rpm-ostree upgrade`, then `flatpak update`. It says when a new system is staged for the next reboot
- `rollback`: `rpm-ostree rollback`, so the previous system boots next. Running it again undoes it. Apps are not rolled back
- `help ["<question>"]`: a chat about this machine, local or main (Help)
- `init`: the steps of setup (Each person), in order: the mesh, the vault, GitHub, the dotfiles, backup. Each step checks first and skips what is done, and asks before it changes anything
	- the mesh is the machine's step: off the mesh, `init` stops
	- it does not make the vault items for backup: it names the two items to make, then stops
	- for backup it creates the repository and starts the first backup
- `version`

## Help

A chat in pi's TUI, with pi's tools off: it answers and tells you what to type, and changes nothing. A question on the command line is its first message.
- online (`nmcli networking connectivity` says `full`): it asks local or main. Enter is local
- offline: local, with no question asked. Local's first reply offers to help get on wifi, so the person can use main. Picked by choice while online, local makes no such offer
- main: the person's own pi, with the provider and model from the config, and every doc in the system prompt. The key file, when there is one, goes to pi in its environment, never on a command line. With no key file, pi uses its own login
- local: llama-server runs the model on the laptop while the chat is open, and stops when it ends. pi reaches it through its own config dir (`~/.local/state/monke/pi-local/`), which knows only this model. Its system prompt is short (`share/monke/local.md`): a 3B model on a laptop CPU is slow to read the whole docs
- the local model: Llama 3.2 3B Instruct, Q4_K_M, 2 GB, pinned by sha256. `monke-model.service` downloads it to `/var/lib/monke/models/` on the first boot that is online, for every person, and retries every 10 minutes until it has it. Boot does not wait for it
- the prompts: `share/monke/`, installed in `/usr/share/monke/`

## Config

Shell `KEY=value` lines, read in this order. A later value replaces an earlier one.
- `/etc/monke/config`: from the image, the same for every person (`etc/monke/config` here)
- `~/.config/monke/config`: the person's own, from their dotfiles

The values, all for `help`:
- `MONKE_MAIN_PROVIDER`, `MONKE_MAIN_MODEL`: main's model, as pi names it. The default is Fireworks' `deepseek-flash-latest` router, which Fireworks moves to each new version
- `MONKE_KEY_FILE`: the file that holds main's API key, written by the person's dotfiles from their vault. The image never holds a key
- `MONKE_LOCAL_MODEL`: the local model's file. It changes with the URL and sha256 in `libexec/monke-model-fetch`
- `MONKE_LOCAL_PORT`: llama-server's port on 127.0.0.1

## Names

The image installs `/usr/bin/monke`. A person calls it by another name with a symlink in their dotfiles, and it names itself by the name it was called by.
- `~/.local/bin/monkey`, a symlink to `/usr/bin/monke`: `monkey help`
- a name with a space is not one command. A shell function in the person's dotfiles takes it, for example `matt() { [ "${1:-}" = matt ] && shift; monke "$@"; }` for `matt matt help`. It works in an interactive shell only

## How the image ships it

- a tag `v*` runs `release.yml`: `scripts/dist.sh` lays the files out at their paths under `/` in `monke.tar.gz`, with `SHA256SUMS`, and makes a GitHub release
	- `/usr/bin/monke`, `/usr/libexec/monke-model-fetch`, `/usr/lib/systemd/system/monke-model.service`, `/usr/share/monke/`, `/etc/monke/config`
- the monkeyimage recipe's `monke` stage takes the latest release at each build and checks it against its `SHA256SUMS`, so a new tag reaches the image at the next daily build
- the image also carries llama-server, from llama.cpp's own CPU build in its `llama.cpp` stage, and enables `monke-model.service`

## Checks

`just check` runs `scripts/check.sh`: the note lint (basis), shellcheck, and the tests in `.tests/`. The tests run every command with stub tools, so nothing touches the machine, the network or a vault.
