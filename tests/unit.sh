#!/bin/bash
# tests/unit.sh — unit tests for lib/gmx.sh helpers
# Run from repo root: bash gromacs-pipeline/tests/unit.sh
set +euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PIPELINE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source the library (defines functions, sets GMX="" etc.)
. "$PIPELINE_DIR/lib/gmx.sh"
set +euo pipefail  # re-source re-enables; disable for tests
GMX="$SCRIPT_DIR/bin/fake_gmx"
GMX_VERSION=2023.2

PASS=0 FAIL=0
ok()   { PASS=$((PASS+1)); echo "  OK: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

echo "=== Unit tests ==="

# ── walltime_to_seconds ──
echo ""
echo "walltime_to_seconds:"
for tc in "24:00:00 86400" "00:30:00 1800" "01:02:03 3723" "00:00:05 5"; do
    input=$(echo "$tc" | awk '{print $1}')
    expected=$(echo "$tc" | awk '{print $2}')
    got=$(walltime_to_seconds "$input")
    [ "$got" = "$expected" ] && ok "\"$input\" -> $expected" || fail "\"$input\" -> $got (expected $expected)"
done

# ── time comparisons ──
echo ""
echo "time_gte:"
time_gte 5 5 && ok "5 >= 5" || fail "5 >= 5"
time_gte 6 5 && ok "6 >= 5" || fail "6 >= 5"
time_gte 4 5 && { fail "4 >= 5 should be false"; } || ok "4 >= 5 is false"
time_gte 1000.1 1000 && ok "1000.1 >= 1000" || fail "1000.1 >= 1000"

echo ""
echo "time_lt:"
time_lt 4 5 && ok "4 < 5" || fail "4 < 5"
time_lt 5 5 && { fail "5 < 5 should be false"; } || ok "5 < 5 is false"
time_lt 6 5 && { fail "6 < 5 should be false"; } || ok "6 < 5 is false"

echo ""
echo "time_min:"
got=$(time_min 3 5); [ "$got" = "3" ] && ok "min(3,5)=3" || fail "min(3,5)=$got"
got=$(time_min 7 2); [ "$got" = "2" ] && ok "min(7,2)=2" || fail "min(7,2)=$got"
got=$(time_min 4.5 4.5); [ "$got" = "4.5" ] && ok "min(4.5,4.5)=4.5" || fail "min(4.5,4.5)=$got"

# ── checkpoint_time_ps ──
echo ""
echo "checkpoint_time_ps:"

# Valid checkpoint
tmpd=$(mktemp -d)
echo "t = 1447.200000" > "$tmpd/md.cpt"
echo "step = 723600" >> "$tmpd/md.cpt"
got=$(checkpoint_time_ps "$tmpd/md.cpt" 0.002)
[ "$got" = "1447.200000" ] && ok "valid checkpoint reads t=1447.2" || fail "got $got"
rm -rf "$tmpd"

# Missing checkpoint
got=$(checkpoint_time_ps "/nonexistent/md.cpt")
[ "$got" = "0" ] && ok "missing checkpoint returns 0" || fail "got $got"

# Corrupt checkpoint
tmpd=$(mktemp -d)
echo "CORRUPT DATA" > "$tmpd/md.cpt"
if checkpoint_time_ps "$tmpd/md.cpt" 0.002 2>/dev/null; then
    fail "corrupt checkpoint should fail"
else
    ok "corrupt checkpoint fails loudly"
fi
rm -rf "$tmpd"

# Inconsistent checkpoint (t != step*dt)
tmpd=$(mktemp -d)
echo "t = 100.0" > "$tmpd/md.cpt"
echo "step = 999999" >> "$tmpd/md.cpt"  # 999999*0.002 = 1999.998 != 100
if checkpoint_time_ps "$tmpd/md.cpt" 0.002 2>/dev/null; then
    fail "inconsistent checkpoint should fail"
else
    ok "inconsistent checkpoint fails loudly"
fi
rm -rf "$tmpd"

# ── production_dt ──
echo ""
echo "production_dt:"
tmpd=$(mkdir -p "$tmpd/mdp" && echo "$tmpd")
echo "dt = 0.004" > "$tmpd/mdp/md.mdp"
MD_MDP="$tmpd/mdp/md.mdp"
got=$(production_dt)
[ "$got" = "0.004" ] && ok "parses dt=0.004" || fail "got $got"
unset MD_MDP
got=$(production_dt)
[ "$got" = "0.002" ] && ok "default dt=0.002" || fail "got $got"
rm -rf "$tmpd"

# ── Summary ──
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
