#!/bin/bash
# tests/test_prepare.sh — Tests for post/prepare.sh trajectory preparation
set +euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PIPELINE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PREPARE="$PIPELINE_DIR/post/prepare.sh"

PASS=0
FAIL=0
ok()   { PASS=$((PASS+1)); echo "  OK: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

echo "=== Tests: post/prepare.sh ==="

# ── Setup: create fake production outputs ────────────────────────────────────
setup_project() {
    local proj="$1"
    rm -rf "$proj"
    mkdir -p "$proj"/output/{production,setup,prepared}
    # Fake md.tpr (empty file — trjconv won't actually run)
    touch "$proj/output/production/md.tpr"
    # Fake md.xtc (empty file)
    touch "$proj/output/production/md.xtc"
    # Fake index.ndx
    echo "[
 Protein_DNA ]" > "$proj/output/setup/index.ndx"
}

teardown_project() { rm -rf "$1"; }

# ── TEST 1: Missing project directory ────────────────────────────────────────
echo ""
echo "TEST 1: missing project directory"
if bash "$PREPARE" /nonexistent/path 2>/dev/null; then
    fail "should fail with missing directory"
else
    ok "fails with missing directory"
fi

# ── TEST 2: Missing trajectory ──────────────────────────────────────────────
echo ""
echo "TEST 2: missing trajectory"
setup_project /tmp/prepare_test2
rm -f /tmp/prepare_test2/output/production/md.xtc
cd /tmp/prepare_test2
if bash "$PREPARE" . 2>/dev/null; then
    fail "should fail with missing trajectory"
else
    ok "fails with missing trajectory"
fi
cd /tmp
teardown_project /tmp/prepare_test2

# ── TEST 3: Missing TPR ────────────────────────────────────────────────────
echo ""
echo "TEST 3: missing TPR"
setup_project /tmp/prepare_test3
rm -f /tmp/prepare_test3/output/production/md.tpr
cd /tmp/prepare_test3
if bash "$PREPARE" . 2>/dev/null; then
    fail "should fail with missing TPR"
else
    ok "fails with missing TPR"
fi
cd /tmp
teardown_project /tmp/prepare_test3

# ── TEST 4: Unknown preset ──────────────────────────────────────────────────
echo ""
echo "TEST 4: unknown preset"
setup_project /tmp/prepare_test4
cd /tmp/prepare_test4
if bash "$PREPARE" . --preset nonexistent 2>/dev/null; then
    fail "should fail with unknown preset"
else
    ok "fails with unknown preset"
fi
cd /tmp
teardown_project /tmp/prepare_test4

# ── TEST 5: Unknown option ──────────────────────────────────────────────────
echo ""
echo "TEST 5: unknown option"
setup_project /tmp/prepare_test5
cd /tmp/prepare_test5
if bash "$PREPARE" . --badoption 2>/dev/null; then
    fail "should fail with unknown option"
else
    ok "fails with unknown option"
fi
cd /tmp
teardown_project /tmp/prepare_test5

# ── TEST 6: Help flag ───────────────────────────────────────────────────────
echo ""
echo "TEST 6: --help"
# --help should exit 0 and print usage, regardless of project path
output=$(bash "$PREPARE" /tmp --help 2>&1 || true)
if echo "$output" | grep -q "Usage:"; then
    ok "--help shows usage"
else
    fail "--help does not show usage (output: $(echo "$output" | head -3))"
fi

# ── TEST 7: Preset parsing (visualization) ──────────────────────────────────
echo ""
echo "TEST 7: preset parsing"
setup_project /tmp/prepare_test7
cd /tmp/prepare_test7
# Test that preset is accepted (will fail at trjconv but parses correctly)
output=$(bash "$PREPARE" . --preset visualization 2>&1 || true)
if echo "$output" | grep -q "Preset 'visualization' applied"; then
    ok "visualization preset parsed correctly"
else
    fail "visualization preset not parsed"
fi
cd /tmp
teardown_project /tmp/prepare_test7

# ── TEST 8: Preset parsing (analysis) ───────────────────────────────────────
echo ""
echo "TEST 8: preset analysis"
setup_project /tmp/prepare_test8
cd /tmp/prepare_test8
output=$(bash "$PREPARE" . --preset analysis 2>&1 || true)
if echo "$output" | grep -q "Preset 'analysis' applied"; then
    ok "analysis preset parsed correctly"
else
    fail "analysis preset not parsed"
fi
cd /tmp
teardown_project /tmp/prepare_test8

# ── TEST 9: Preset parsing (dry) ────────────────────────────────────────────
echo ""
echo "TEST 9: preset dry"
setup_project /tmp/prepare_test9
cd /tmp/prepare_test9
output=$(bash "$PREPARE" . --preset dry 2>&1 || true)
if echo "$output" | grep -q "Preset 'dry' applied"; then
    ok "dry preset parsed correctly"
else
    fail "dry preset not parsed"
fi
cd /tmp
teardown_project /tmp/prepare_test9

# ── TEST 10: No flags defaults to --center-on Protein ───────────────────────
echo ""
echo "TEST 10: default center-on"
setup_project /tmp/prepare_test10
cd /tmp/prepare_test10
output=$(bash "$PREPARE" . 2>&1 || true)
if echo "$output" | grep -q "centering on Protein"; then
    ok "defaults to center-on Protein"
else
    fail "does not default to center-on Protein"
fi
cd /tmp
teardown_project /tmp/prepare_test10

# ── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
