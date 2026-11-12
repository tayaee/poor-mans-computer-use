#!/bin/sh
# release-patch.sh — cut a patch release end to end.
# Usage: ./release-patch.sh [<commit-message>]  (omitted: generated via ./cm.sh)
set -eu
cd "$(dirname "$0")"
(set -x; ./1-add.sh)
(set -x; ./2-code-quality-gate.sh)
(set -x; ./3-build.sh)
if [ $# -ge 1 ]; then (set -x; ./4-commit.sh "$1"); else (set -x; ./4-commit.sh); fi
(set -x; ./5-bump-version.sh --patch)
(set -x; ./6-tag.sh)
(set -x; ./7-push.sh)
