#!/bin/sh
# run-regression.sh — end-to-end sanity against a fresh release build.
# version: host-independent, must always succeed (catches broken installs).
# status: verifies interop wiring.
# windows list: host smoke, only when a Windows host answers (skipped on
# host-less CI runners so the gate stays green there).
set -eu
cargo build --release
BIN=./target/release/pmcu
"$BIN" version
"$BIN" status > /tmp/pmcu-status.json
cat /tmp/pmcu-status.json
echo
if grep -q '"powershell_reachable":true' /tmp/pmcu-status.json; then
    "$BIN" windows list --only chrome > /dev/null
    echo "[regression] host smoke ok"
else
    echo "[regression] no Windows host — local smoke only"
fi
