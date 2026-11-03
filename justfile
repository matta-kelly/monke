set positional-arguments

root := justfile_directory()

# The check set: scripts/check.sh, on a machine and in checks.yml. It runs only the sets a change touches.
check:
    scripts/check.sh

# Lint the notes, in the Node image.
lint:
    @just _node npm run --silent lint

# shellcheck on every script, in a pinned image, never on the host.
shellcheck_image := "docker.io/koalaman/shellcheck:v0.11.0@sha256:b9389b73c8f26f710a7171cb7d8848a34a9c1e07a7865e727c9ec4ce99f9a83f"

shellcheck:
    @podman run --rm --security-opt label=disable -v "{{root}}:/mnt" -w /mnt {{shellcheck_image}} bin/monke libexec/monke-model-fetch scripts/*.sh .tests/*.sh

# The lint runs in this pinned Node image, never on the host, and installs only when the lockfile is newer.
node_image := "docker.io/library/node:22.23.4-slim"

_node +command:
    @podman run --rm --userns=keep-id:uid=1000,gid=1000 --security-opt label=disable --cpus=3 --cpu-shares=256 -u node -e NPM_CONFIG_UPDATE_NOTIFIER=false -v "{{root}}:{{root}}" -w "{{root}}" {{node_image}} sh -c '[ node_modules/.package-lock.json -nt package-lock.json ] || npm ci --ignore-scripts --no-audit --no-fund >/dev/null; '"$*"
