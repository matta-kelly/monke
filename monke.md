---
type: component
description: "monke, the CLI of Monkeyworks: one bash script that wraps the machine's own tools and prints each command it runs. Its commands, its config, how each person names it, and what is built. Read before changing the CLI or how the image ships it."
status: planned
---
monke: the front door of [[monkeyworks]]. A bash script that wraps the tools the machine already has, and prints each command before it runs it, so the user sees what it does and can do it by hand.
- Commands: what each one does
- Config: where its values come from
- Names: how each person calls it by their own name
- How the image ships it

Built: every command, the config, and the tests. Not built: the image stage, and a model for `help` (`MONKE_MODEL` is empty). Not yet run on a real machine.

---
## Commands

Each command prints what it runs: `+ cmd` for a command that does something, `? cmd` for a check that changes nothing.
- `status`: `rpm-ostree status` (the booted, staged and rollback systems), the installed apps, and the app updates there are
- `update`: `rpm-ostree upgrade`, then `flatpak update`. It says when a new system is staged for the next reboot
- `rollback`: `rpm-ostree rollback`, so the previous system boots next. Running it again undoes it. Apps are not rolled back
- `help "<question>"`: one request to the model, with every doc in `/usr/share/doc/monkeyworks/` as context. It answers and changes nothing. The key goes in a header from a file descriptor, never on a command line
- `init`: the steps of setup (Each person), in order: the mesh, the vault, GitHub, the dotfiles, backup. Each step checks first and skips what is done, and asks before it changes anything
	- the mesh is the machine's step: off the mesh, `init` stops
	- it does not make the vault items for backup: it names the two items to make, then stops
	- for backup it creates the repository and starts the first backup
- `version`

## Config

Shell `KEY=value` lines, read in this order. A later value replaces an earlier one.
- `/etc/monke/config`: from the image, the same for every person (`etc/monke/config` here)
- `~/.config/monke/config`: the person's own, from their dotfiles

The values, all for `help`:
- `MONKE_ENDPOINT`: any server with the OpenAI chat API. Fireworks, or a local model server
- `MONKE_MODEL`: the model to ask
- `MONKE_KEY_FILE`: the file that holds the API key, written by the person's dotfiles from their vault. The image never holds a key

## Names

The image installs `/usr/bin/monke`. A person calls it by another name with a symlink in their dotfiles, and it names itself by the name it was called by.
- `~/.local/bin/monkey`, a symlink to `/usr/bin/monke`: `monkey help`
- a name with a space is not one command. A shell function in the person's dotfiles takes it, for example `matt() { [ "${1:-}" = matt ] && shift; monke "$@"; }` for `matt matt help`. It works in an interactive shell only

## How the image ships it

A build stage in the monkeyimage recipe, the same as keyd's: it downloads a tagged release of this repo, checks it against a pinned sha256, and copies `bin/monke` to `/usr/bin/` and `etc/monke/config` to `/etc/monke/`. A new version is a new tag here, then the version and sha256 together in the recipe.

## Checks

`just check` runs `scripts/check.sh`: the note lint (basis), shellcheck, and the tests in `.tests/`.
