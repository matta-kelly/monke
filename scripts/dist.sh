#!/usr/bin/env bash
# Builds the release: dist/monke.tar.gz, its files at the paths they install to under /, and dist/SHA256SUMS.
# The monkeyimage recipe's monke stage unpacks it into the image.
set -euo pipefail
cd "$(dirname "$0")/.."

root=dist/root
rm -rf dist
install -Dm755 bin/monke "$root/usr/bin/monke"
# The version is the tag: the release workflow's ref name, or else the newest tag here.
version=${GITHUB_REF_NAME:-$(git describe --tags --always)}
sed -i "s/^version=dev .*/version=${version#v}/" "$root/usr/bin/monke"
install -Dm755 libexec/monke-model-fetch "$root/usr/libexec/monke-model-fetch"
install -Dm644 systemd/monke-model.service "$root/usr/lib/systemd/system/monke-model.service"
install -Dm644 -t "$root/usr/share/monke" share/monke/*.md
install -Dm644 etc/monke/config "$root/etc/monke/config"
install -Dm644 monke.md "$root/usr/share/doc/monkeyworks/monke.md" # beside the machine's docs, which link it and help reads

tar --owner=0 --group=0 --numeric-owner -czf dist/monke.tar.gz -C "$root" .
(cd dist && sha256sum monke.tar.gz >SHA256SUMS)
rm -rf "$root" # only the tarball is the release; a staged copy of monke.md would be a second note
tar -tzf dist/monke.tar.gz
