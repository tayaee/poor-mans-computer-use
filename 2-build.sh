#!/bin/sh
# 3-build.sh — local release verification build (real release is built by CI).
set -eu
cargo build --release
./target/release/pmcu status
ls -lh target/release/pmcu
echo "[build] ok"
