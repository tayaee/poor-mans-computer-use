#!/bin/bash
# 1-code-quality-gate: chain the quality tools into a single gate.
# Each step runs sequentially; any FAIL exits non-zero at the end.
# Exit 2 from a step means SKIP (tool not installed) -- counted, never fails.
# Mirrors the python-gate harness: "=== name: purpose ===" headers make the
# output self-documenting for first-time readers.
cd "$(dirname "$0")"
set -u

pass=0
fail=0
skipped=0
failed_tools=()

# run_one <name> <purpose> <command...>
run_one() {
    local name="$1"
    local purpose="$2"
    shift 2
    echo "=== $name: $purpose ==="
    if "$@" >/tmp/cqg-$name.log 2>&1; then
        echo "PASS: $name"
        pass=$((pass + 1))
    else
        local rc=$?
        if [ "$rc" -eq 2 ]; then
            echo "SKIP: $name (see /tmp/cqg-$name.log)"
            skipped=$((skipped + 1))
        else
            echo "FAIL: $name"
            fail=$((fail + 1))
            failed_tools+=("$name")
        fi
    fi
}

# need <binary>: SKIP the step when the tool is not installed.
need() {
    command -v "$1" >/dev/null 2>&1 || { echo "missing tool: $1"; return 2; }
}

step_audit() {
    need cargo-audit || return 2
    cargo audit
}

step_geiger() {
    need cargo-geiger || return 2
    cargo geiger --forbid-only --all-targets
}

step_gitleaks() {
    need gitleaks || return 2
    gitleaks detect --source . --no-git -v
}

# fmt: rustfmt formatting check. Non-mutating; run `cargo fmt` to auto-fix.
run_one fmt \
    "formatting check (rustfmt, non-mutating)" \
    cargo fmt --check

# clippy: the linter. -D warnings turns every lint into a gate failure.
run_one clippy \
    "lints (style + likely-bug patterns, warnings denied)" \
    cargo clippy --all-targets -- -D warnings

# test: actual test execution. The only step that exercises runtime behavior.
run_one test \
    "unit + integration tests (cargo test)" \
    cargo test

# audit: dependency vulnerability scan. RustSec advisory DB against Cargo.lock.
# Zero deps today so instant pass; future-proofs the first added dependency.
run_one audit \
    "dependency vulnerability scan (RustSec, skipped if cargo-audit missing)" \
    step_audit

# geiger: unsafe-code audit. Counts `unsafe` blocks -- the one thing the
# compiler cannot check for us. Matters the moment Win32 FFI lands.
run_one geiger \
    "unsafe usage audit (skipped if cargo-geiger missing)" \
    step_geiger

# gitleaks: secret scan. Language-agnostic; catches credentials in the tree.
run_one gitleaks \
    "secret scan (skipped if gitleaks missing)" \
    step_gitleaks

# regression: end-to-end sanity against a fresh release build.
# version (host-independent) -> status -> host smoke only when a Windows
# host answers, so the gate stays green on host-less CI runners too.
run_one regression \
    "release build + version/status smoke (+host list when reachable)" \
    ./scripts/run-regression.sh

echo
echo "Summary: $pass passed, $fail failed, $skipped skipped"
if [ "$fail" -gt 0 ]; then
    echo "Failed tools: ${failed_tools[*]}"
    for t in "${failed_tools[@]}"; do
        echo "--- $t log tail ---"
        tail -20 "/tmp/cqg-$t.log"
    done
    exit 1
fi
echo "All quality gates passed."
