#!/bin/sh
# 4-tag.sh — tag the current Cargo.toml version. Run after 3-build.sh passes.
set -eu
CUR="$(sed -n 's/^version = "\(.*\)"/\1/p' Cargo.toml | head -n 1)"
[ -n "$CUR" ] || { echo "[tag] cannot read version from Cargo.toml" >&2; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "[tag] dirty tree — commit first" >&2; exit 1; }
if git rev-parse "v$CUR" >/dev/null 2>&1; then
    echo "[tag] v$CUR already exists" >&2; exit 1
fi
git tag "v$CUR"
echo "[tag] tagged v$CUR — run ./5-push.sh to publish"
