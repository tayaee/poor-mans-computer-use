#!/bin/sh
# 5-push.sh — push branch + tags; tag push triggers the release workflow.
set -eu
BRANCH="$(git branch --show-current)"
git push origin "$BRANCH"
git push origin --tags
echo "[push] pushed $BRANCH + tags"

VER="v$(sed -n 's/^version = "\(.*\)"/\1/p' Cargo.toml | head -n 1)"
echo "[push] waiting for release $VER (max 120s)..."
i=0
while [ "$i" -lt 24 ]; do
    if gh release view "$VER" >/dev/null 2>&1; then
        echo "[push] release $VER published:"
        gh release view "$VER" --json assets --jq '.assets[].name'
        exit 0
    fi
    CONCL="$(gh run list --workflow release.yml --limit 1 --json status,conclusion --jq '.[0] | "\(.status)/\(.conclusion)"' 2>/dev/null || echo "?/?")"
    case "$CONCL" in
        completed/failure|completed/cancelled|completed/timed_out|completed/action_required)
            echo "[push] workflow ended: $CONCL" >&2; exit 1;;
    esac
    sleep 5; i=$((i + 1))
done
echo "[push] timed out waiting for $VER" >&2; exit 1
