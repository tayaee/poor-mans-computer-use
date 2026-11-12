#!/bin/sh
# 3-bump-version.sh — bump Cargo.toml and commit. Tagging is 4-tag.sh.
# Usage: ./3-bump-version.sh --major | --minor | --patch | <x.y.z>
set -eu

usage() {
    echo "Usage: ./3-bump-version.sh --major | --minor | --patch | <x.y.z>" >&2
    echo "  --major  0.1.0 -> 1.0.0 (breaking changes)" >&2
    echo "  --minor  0.1.0 -> 0.2.0 (new features, backwards compatible)" >&2
    echo "  --patch  0.1.0 -> 0.1.1 (bug fixes only)" >&2
    exit 1
}

CUR="$(sed -n 's/^version = "\(.*\)"/\1/p' Cargo.toml | head -n 1)"
[ -n "$CUR" ] || { echo "[bump] cannot read version from Cargo.toml" >&2; exit 1; }

if [ $# -eq 0 ]; then
    echo "[bump] current version: $CUR" >&2
    usage
fi

case "$1" in
    --major|--minor|--patch)
        MAJOR="${CUR%%.*}"; REST="${CUR#*.}"
        MINOR="${REST%%.*}"; PATCH="${REST#*.}"
        case "$1" in
            --major) NEW="$((MAJOR + 1)).0.0";;
            --minor) NEW="$MAJOR.$((MINOR + 1)).0";;
            --patch) NEW="$MAJOR.$MINOR.$((PATCH + 1))";;
        esac
        ;;
    *)
        NEW="$1"
        case "$NEW" in
            *[!0-9.]*|*..*|.*|*.) echo "[bump] bad version: $NEW" >&2; usage;;
        esac
        ;;
esac

[ -z "$(git status --porcelain)" ] || { echo "[bump] dirty tree — commit first" >&2; exit 1; }
sed -i "s/^version = \".*\"/version = \"$NEW\"/" Cargo.toml
grep -q "^version = \"$NEW\"$" Cargo.toml || { echo "[bump] Cargo.toml update failed" >&2; exit 1; }
git add Cargo.toml
git commit -m "chore: bump to v$NEW"
echo "[bump] $CUR -> $NEW committed — verify with ./3-build.sh, tag with ./4-tag.sh"
