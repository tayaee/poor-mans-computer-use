#!/bin/sh
# 1-add.sh — stage tracked updates; also stage new files if any appear.
set -eu
git add -u
NEW="$(git ls-files --others --exclude-standard)"
if [ -n "$NEW" ]; then
    # shellcheck disable=SC2086
    echo "$NEW" | xargs git add --
    echo "[add] staged new files:"
    echo "$NEW"
fi
echo "[add] staged:"
git diff --cached --name-only
