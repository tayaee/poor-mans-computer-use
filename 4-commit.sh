#!/bin/sh
# 4-commit.sh — commit staged changes.
# Usage: ./4-commit.sh [<message>]  (omitted: generate via ./cm.sh)
set -eu
git diff --cached --quiet && { echo "[commit] nothing staged — run ./1-add.sh first" >&2; exit 1; }
MSG="${1:-"$(dirname "$0")/cm.sh"}"
git commit -m "$MSG"
