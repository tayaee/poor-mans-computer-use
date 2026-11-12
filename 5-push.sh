#!/bin/sh
# 5-push.sh — push branch + tags; tag push triggers the release workflow.
set -eu
BRANCH="$(git branch --show-current)"
git push origin "$BRANCH"
git push origin --tags
echo "[push] pushed $BRANCH + tags — watch Actions to publish the release"
